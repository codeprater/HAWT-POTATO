import SwiftUI
import HAWTPotatoCore

struct QuickShareRequest: Identifiable {
    let card: HotPotatoCard
    let destination: PotatoShareDestination
    var recipients: [String] = []

    var id: String { "\(card.id.uuidString)-\(destination.id)-\(recipients.joined())" }
}

struct QuickSendButtons: View {
    let card: HotPotatoCard
    var onShare: (PotatoShareDestination) -> Void
    var onPass: (PlayerRef, NearbyPeer?) -> Void
    var onMessageContact: ((PhoneContact) -> Void)? = nil

    @Environment(PotatoStore.self) private var store
    @Bindable private var nearby = NearbyThrowService.shared
    @Bindable private var contacts = ContactDirectory.shared

    var body: some View {
        Button {
            onShare(.messages)
        } label: {
            Label("Throw into iMessage", systemImage: "bubble.left.and.bubble.right.fill")
        }
        Button {
            onShare(.airDrop)
        } label: {
            Label("AirDrop", systemImage: "square.and.arrow.up")
        }
        let people = Array(contacts.contacts.prefix(8))
        if !people.isEmpty {
            Divider()
            ForEach(people) { contact in
                Button("iMessage \(contact.name)") {
                    onMessageContact?(contact)
                }
            }
        }
        let peers = nearby.peers.filter { !store.isBlocked($0.player) }
        if !peers.isEmpty {
            Divider()
            ForEach(peers) { peer in
                Button("Pass to \(peer.displayName)") {
                    onPass(peer.player, peer)
                }
            }
        }
        let recent = store.visibleRecentPlayers.prefix(6)
        if !recent.isEmpty {
            Divider()
            ForEach(Array(recent)) { player in
                Button("Dump on \(player.displayName)") {
                    onPass(player, nearby.peers.first { $0.playerID == player.id })
                }
            }
        }
    }
}

extension View {
    func quickSendMenu(
        card: HotPotatoCard,
        me: PlayerRef,
        onShare: @escaping (PotatoShareDestination) -> Void,
        onPass: @escaping (PlayerRef, NearbyPeer?) -> Void,
        onMessageContact: ((PhoneContact) -> Void)? = nil
    ) -> some View {
        contextMenu {
            if card.isHeld(by: me), card.status != .exploded {
                QuickSendButtons(
                    card: card,
                    onShare: onShare,
                    onPass: onPass,
                    onMessageContact: onMessageContact
                )
            }
        }
    }
}
