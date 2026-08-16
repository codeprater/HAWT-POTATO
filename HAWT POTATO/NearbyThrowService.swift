import Foundation
import Network
import HAWTPotatoCore

struct NearbyPeer: Identifiable, Equatable {
    var id: String { playerID }
    var playerID: String
    var displayName: String
    var endpoint: NWEndpoint?

    var player: PlayerRef {
        PlayerRef(id: playerID, displayName: displayName)
    }
}

private struct NearbyMessage: Codable {
    enum Kind: String, Codable { case hello, potato }
    var kind: Kind
    var playerID: String?
    var displayName: String?
    var card: HotPotatoCard?
}

@MainActor
@Observable
final class NearbyThrowService {
    static let shared = NearbyThrowService()

    var peers: [NearbyPeer] = []
    var lastReceived: HotPotatoCard?
    var receiveStamp = UUID()
    var lastError: String?
    var connectedPeerIDs: Set<String> = []

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var connections: [String: NWConnection] = [:]
    @ObservationIgnored private var inbound: [ObjectIdentifier: NWConnection] = [:]
    @ObservationIgnored private var buffers: [ObjectIdentifier: Data] = [:]
    @ObservationIgnored private var pending: [String: HotPotatoCard] = [:]
    @ObservationIgnored private var me: PlayerRef?
    @ObservationIgnored private var started = false

    func start(as player: PlayerRef) {
        if started, me?.id == player.id, listener != nil, browser != nil {
            reconnectMissing()
            return
        }
        stop()
        me = player
        started = true
        startListener()
        startBrowser()
    }

    func stop() {
        browser?.cancel()
        listener?.cancel()
        for connection in connections.values { connection.cancel() }
        for connection in inbound.values { connection.cancel() }
        browser = nil
        listener = nil
        connections = [:]
        inbound = [:]
        buffers = [:]
        pending = [:]
        peers = []
        connectedPeerIDs = []
        started = false
    }

    func throwTo(_ peer: NearbyPeer, card: HotPotatoCard) {
        lastError = nil
        pending[peer.playerID] = card
        if sendPotato(card, to: peer.playerID) { return }
        connect(to: peer, force: true)
    }

    func isConnected(_ peer: NearbyPeer) -> Bool {
        connectedPeerIDs.contains(peer.playerID)
    }

    func broadcast(_ card: HotPotatoCard) {
        let message = NearbyMessage(kind: .potato, playerID: me?.id, displayName: me?.displayName, card: card)
        for connection in connections.values where connection.state == .ready {
            send(message, on: connection)
        }
    }

    private func startListener() {
        guard let me else { return }
        do {
            let listener = try NWListener(using: makeParameters())
            var txt = NWTXTRecord()
            txt["id"] = me.id
            txt["name"] = me.displayName
            listener.service = NWListener.Service(
                name: serviceName(for: me),
                type: "_\(ProductCanon.nearbyServiceType)._tcp",
                txtRecord: txt
            )
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    if case .failed = state {
                        self?.restartListener()
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.attach(connection, playerID: nil)
                }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            lastError = "Couldn't open nearby. Keep both apps on screen."
        }
    }

    private func restartListener() {
        listener?.cancel()
        listener = nil
        guard started else { return }
        startListener()
    }

    private func startBrowser() {
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: "_\(ProductCanon.nearbyServiceType)._tcp", domain: nil),
            using: makeParameters()
        )
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .failed = state {
                    self?.restartBrowser()
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.applyBrowseResults(results)
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    private func restartBrowser() {
        browser?.cancel()
        browser = nil
        guard started else { return }
        startBrowser()
    }

    private func applyBrowseResults(_ results: Set<NWBrowser.Result>) {
        guard let me else { return }
        var next: [NearbyPeer] = []
        for result in results {
            let identity = identity(from: result)
            guard identity.playerID != me.id else { continue }
            let peer = NearbyPeer(
                playerID: identity.playerID,
                displayName: identity.displayName,
                endpoint: result.endpoint
            )
            next.append(peer)
            if connections[peer.playerID]?.state != .ready {
                connect(to: peer, force: shouldInitiate(peer.playerID))
            }
        }
        for (id, connection) in connections where connection.state == .ready {
            if !next.contains(where: { $0.playerID == id }) {
                let name = peers.first(where: { $0.playerID == id })?.displayName ?? id
                next.append(NearbyPeer(playerID: id, displayName: name, endpoint: nil))
            }
        }
        peers = next
        reconnectMissing()
    }

    private func identity(from result: NWBrowser.Result) -> (playerID: String, displayName: String) {
        if case .bonjour(let txt) = result.metadata {
            let id = txt["id"] ?? fallbackID(from: result.endpoint)
            let name = txt["name"] ?? fallbackName(from: result.endpoint)
            return (id, name)
        }
        return (fallbackID(from: result.endpoint), fallbackName(from: result.endpoint))
    }

    private func fallbackName(from endpoint: NWEndpoint) -> String {
        if case .service(let name, _, _, _) = endpoint { return name }
        return "Nearby player"
    }

    private func fallbackID(from endpoint: NWEndpoint) -> String {
        if case .service(let name, _, _, _) = endpoint { return name }
        return String(describing: endpoint)
    }

    private func shouldInitiate(_ theirID: String) -> Bool {
        guard let mine = me?.id else { return true }
        return mine < theirID
    }

    private func reconnectMissing() {
        for peer in peers {
            let connection = connections[peer.playerID]
            if connection == nil || isDead(connection?.state) {
                connect(to: peer, force: shouldInitiate(peer.playerID) || pending[peer.playerID] != nil)
            }
        }
    }

    private func connect(to peer: NearbyPeer, force: Bool) {
        guard let endpoint = peer.endpoint else { return }
        if let existing = connections[peer.playerID] {
            switch existing.state {
            case .ready, .preparing, .setup:
                if !force { return }
            default:
                existing.cancel()
                connections[peer.playerID] = nil
            }
        }
        if !force, !shouldInitiate(peer.playerID), pending[peer.playerID] == nil {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard let self else { return }
                if self.connections[peer.playerID]?.state != .ready {
                    self.connect(to: peer, force: true)
                }
            }
            return
        }
        let connection = NWConnection(to: endpoint, using: makeParameters())
        attach(connection, playerID: peer.playerID)
    }

    private func attach(_ connection: NWConnection, playerID: String?) {
        if let playerID {
            connections[playerID] = connection
        } else {
            inbound[ObjectIdentifier(connection)] = connection
        }
        buffers[ObjectIdentifier(connection)] = Data()
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handle(state, on: connection, playerID: playerID)
            }
        }
        connection.start(queue: .main)
        receiveLoop(connection)
    }

    private func handle(_ state: NWConnection.State, on connection: NWConnection, playerID: String?) {
        switch state {
        case .ready:
            sendHello(on: connection)
            if let playerID {
                connectedPeerIDs.insert(playerID)
                flushPending(to: playerID)
            }
        case .failed, .cancelled:
            drop(connection, playerID: playerID)
        default:
            break
        }
    }

    private func drop(_ connection: NWConnection, playerID: String?) {
        let key = ObjectIdentifier(connection)
        inbound[key] = nil
        buffers[key] = nil
        if let playerID {
            if connections[playerID] === connection {
                connections[playerID] = nil
                connectedPeerIDs.remove(playerID)
            }
        } else if let match = connections.first(where: { $0.value === connection })?.key {
            connections[match] = nil
            connectedPeerIDs.remove(match)
        }
        connection.cancel()
    }

    private func receiveLoop(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.ingest(data, from: connection)
                }
                if isComplete || error != nil {
                    let id = self.connections.first(where: { $0.value === connection })?.key
                    self.drop(connection, playerID: id)
                    return
                }
                self.receiveLoop(connection)
            }
        }
    }

    private func ingest(_ chunk: Data, from connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        var buffer = buffers[key] ?? Data()
        buffer.append(chunk)
        while buffer.count >= 4 {
            let length = buffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length > 0, length < 1_000_000 else {
                buffers[key] = Data()
                return
            }
            let total = 4 + Int(length)
            guard buffer.count >= total else { break }
            let payload = buffer.subdata(in: 4..<total)
            buffer.removeSubrange(0..<total)
            handleMessage(payload, from: connection)
        }
        buffers[key] = buffer
    }

    private func handleMessage(_ data: Data, from connection: NWConnection) {
        guard let message = try? JSONDecoder().decode(NearbyMessage.self, from: data) else { return }
        switch message.kind {
        case .hello:
            guard let id = message.playerID, id != me?.id else { return }
            inbound[ObjectIdentifier(connection)] = nil
            connections[id] = connection
            connectedPeerIDs.insert(id)
            if !peers.contains(where: { $0.playerID == id }) {
                peers.append(
                    NearbyPeer(
                        playerID: id,
                        displayName: message.displayName ?? "Nearby player",
                        endpoint: nil
                    )
                )
            }
            flushPending(to: id)
        case .potato:
            guard var card = message.card else { return }
            if let me, card.status != .exploded, card.currentHolder.id != me.id {
                card.currentHolder = me
            }
            lastReceived = card
            receiveStamp = UUID()
        }
    }

    private func sendHello(on connection: NWConnection) {
        guard let me else { return }
        send(
            NearbyMessage(kind: .hello, playerID: me.id, displayName: me.displayName, card: nil),
            on: connection
        )
    }

    @discardableResult
    private func sendPotato(_ card: HotPotatoCard, to playerID: String) -> Bool {
        guard let connection = connections[playerID], connection.state == .ready else { return false }
        send(NearbyMessage(kind: .potato, playerID: me?.id, displayName: me?.displayName, card: card), on: connection)
        pending[playerID] = nil
        lastError = nil
        return true
    }

    private func flushPending(to playerID: String) {
        guard let card = pending[playerID] else { return }
        _ = sendPotato(card, to: playerID)
    }

    private func send(_ message: NearbyMessage, on connection: NWConnection) {
        guard let body = try? JSONEncoder().encode(message) else {
            lastError = "Couldn't pack that potato."
            return
        }
        var packet = Data()
        var length = UInt32(body.count).bigEndian
        packet.append(Data(bytes: &length, count: 4))
        packet.append(body)
        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            Task { @MainActor in
                if error != nil {
                    self?.lastError = "Couldn't reach them. Tap PASS again."
                }
            }
        })
    }

    private func makeParameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 2
        tcp.connectionTimeout = 4
        tcp.noDelay = true
        let params = NWParameters(tls: nil, tcp: tcp)
        params.includePeerToPeer = true
        params.allowLocalEndpointReuse = true
        params.serviceClass = .responsiveData
        return params
    }

    private func isDead(_ state: NWConnection.State?) -> Bool {
        switch state {
        case .failed, .cancelled, .none:
            return true
        default:
            return false
        }
    }

    private func serviceName(for player: PlayerRef) -> String {
        let base = player.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = base.isEmpty ? "Player" : base
        let suffix = String(player.id.suffix(6))
        let raw = "\(name) · \(suffix)"
        return String(raw.prefix(63))
    }
}
