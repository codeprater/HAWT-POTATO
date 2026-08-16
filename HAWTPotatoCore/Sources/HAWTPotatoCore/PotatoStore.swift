import Foundation

@MainActor
@Observable
public final class PotatoStore {
    public var identity: PlayerRef?
    public var hasCompletedOnboarding = false
    public var potatoes: [HotPotatoCard] = []
    public var settings = AppSettings()
    public var profile: PlayerProfile?
    public var recentPlayers: [PlayerRef] = []
    public var blockedPlayers: [PlayerRef] = []
    public var now: Date = .now
    public var lastError: String?
    public var incomingQueue: [UUID] = []
    public var lastHandoff: HandoffNotice?
    public var pauseNotice: PauseNotice?
    public var pauseEpoch = 0
    public var pendingThrowID: UUID?
    public var dismissedNudgeIDs: [String] = []

    @ObservationIgnored private var persistence = LocalPersistence()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var cloud: CloudKitPotatoService?

    public init() {
        let state = persistence.load()
        identity = state.identity
        hasCompletedOnboarding = state.hasCompletedOnboarding
        potatoes = state.potatoes
        settings = state.settings
        profile = state.profile
        recentPlayers = state.recentPlayers
        blockedPlayers = state.blockedPlayers
#if canImport(CloudKit)
        cloud = CloudKitPotatoService()
#endif
        tickExplosions(at: .now)
        startClock()
        Task { await refreshIdentityFromCloud() }
    }

    public var me: PlayerRef {
        identity ?? PlayerRef(id: "local", displayName: "You")
    }

    public var holding: [HotPotatoCard] {
        potatoes.filter { $0.isHeld(by: me) && $0.status != .exploded }
            .sorted { $0.lethalDeadline() < $1.lethalDeadline() }
    }

    public var hottestHeld: HotPotatoCard? { holding.first }

    /// Live potatoes someone else passed to you — drives the Home / app-icon badge.
    public var homeBadgeCount: Int {
        holding.filter { $0.isIncomingCatch(for: me) }.count
    }

    public var watching: [HotPotatoCard] {
        potatoes.filter { $0.status != .exploded && $0.isWatching(me) && !$0.isHeld(by: me) }
            .sorted { $0.lethalDeadline() < $1.lethalDeadline() }
    }

    public var history: [HotPotatoCard] {
        potatoes.filter { $0.status == .exploded }.sorted { ($0.explosion?.explodedAt ?? $0.expiresAt) > ($1.explosion?.explodedAt ?? $1.expiresAt) }
    }

    public var visibleRecentPlayers: [PlayerRef] {
        recentPlayers.filter { !isBlocked($0) }
    }

    public func isBlocked(_ player: PlayerRef) -> Bool {
        blockedPlayers.contains { $0.id == player.id }
    }

    public func block(_ player: PlayerRef) {
        guard player.id != me.id else { return }
        if !blockedPlayers.contains(where: { $0.id == player.id }) {
            blockedPlayers.append(player)
        }
        recentPlayers.removeAll { $0.id == player.id }
        incomingQueue.removeAll { id in
            guard let card = potato(id) else { return false }
            let sender = card.previousHolder ?? card.creator
            return sender.id == player.id
        }
        persist()
    }

    public func unblock(_ player: PlayerRef) {
        blockedPlayers.removeAll { $0.id == player.id }
        persist()
    }

    public func forgetRecent(_ player: PlayerRef) {
        recentPlayers.removeAll { $0.id == player.id }
        persist()
    }

    public var inFlightCatchable: [HotPotatoCard] {
        potatoes.filter { $0.status == .inFlight && !$0.isHeld(by: me) && !$0.isPaused }
            .sorted { $0.lethalDeadline() < $1.lethalDeadline() }
    }

    public func resetAllData() {
        let owned = potatoes.filter { $0.creator.id == me.id }.map(\.id)
        potatoes = []
        profile = nil
        recentPlayers = []
        blockedPlayers = []
        incomingQueue = []
        pendingThrowID = nil
        hasCompletedOnboarding = false
        persist()
        Task {
            for id in owned {
                await deleteRemote(id)
            }
        }
    }

    public var incomingCards: [HotPotatoCard] {
        incomingQueue.compactMap(potato)
            .filter { $0.isHeld(by: me) && $0.status != .exploded }
            .sorted { $0.lethalDeadline() < $1.lethalDeadline() }
    }

    public var frontIncoming: HotPotatoCard? { incomingCards.first }

    public var queuedIncomingCount: Int {
        max(0, incomingCards.count - (frontIncoming == nil ? 0 : 1))
    }

    public func completeOnboarding(displayName: String) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = DisplayNameRules.sanitized(trimmed)
        let id = identity?.id ?? UUID().uuidString
        identity = PlayerRef(id: id, displayName: name)
        profile = PlayerProfile(identity: identity!)
        hasCompletedOnboarding = true
        persist()
        Task { await refreshIdentityFromCloud() }
    }

    public func lightPotato(duration: TimeInterval, locationSharing: LocationSharing, location: LocationSnapshot?, gameMode: GameMode, theme: String, nickname: String? = nil, note: String? = nil) -> HotPotatoCard {
        settings.locationSharing = locationSharing
        let card = HotPotatoCard.light(
            by: me,
            duration: duration,
            locationSharing: locationSharing,
            location: location,
            gameMode: gameMode,
            theme: theme,
            nickname: DisplayNameRules.sanitizedNickname(nickname ?? ""),
            note: DisplayNameRules.sanitizedNote(note ?? "")
        )
        upsert(card)
        profile?.totalThrows += 0
        if gameMode == .suddenDeath {
            enqueueIncoming(card.id)
        }
        persist()
        Task(priority: .userInitiated) { await push(card) }
        return card
    }

    public func throwPotato(_ id: UUID, to target: PlayerRef, location: LocationSnapshot?) throws {
        guard var card = potato(id) else { throw PotatoError.unknownPotato }
        guard card.isHeld(by: me) else { throw PotatoError.notHolder }
        let holdTime = card.duration - card.remaining()
        try card.throwTo(target, location: location)
        remember(target)
        profile?.passed += 1
        profile?.totalThrows += 1
        if profile?.fastestPass == nil || holdTime < (profile?.fastestPass ?? holdTime) {
            profile?.fastestPass = holdTime
        }
        if profile?.longestSafeHold == nil || holdTime > (profile?.longestSafeHold ?? 0) {
            profile?.longestSafeHold = holdTime
        }
        upsert(card)
        lastHandoff = HandoffNotice(recipientName: target.displayName, callsign: card.callsign, at: .now)
        persist()
        Task(priority: .userInitiated) { await push(card) }
        pruneIncoming()
    }

    public func clearHandoff() {
        lastHandoff = nil
    }

    public func offerPotatoToGroup(_ id: UUID) throws {
        guard var card = potato(id) else { throw PotatoError.unknownPotato }
        try card.offerToGroup(from: me)
        upsert(card)
        persist()
        Task(priority: .userInitiated) { await push(card) }
        pruneIncoming()
    }

    public func claimPotato(_ id: UUID, location: LocationSnapshot?) throws {
        guard var card = potato(id) else { throw PotatoError.unknownPotato }
        try card.claim(by: me, location: location)
        profile?.received += 1
        enqueueIncoming(card.id)
        upsert(card)
        persist()
        Task(priority: .userInitiated) { await push(card) }
    }

    public func ingest(_ card: HotPotatoCard, asReceive: Bool, syncCloud: Bool = false) {
        var incoming = card
        if let existing = potato(card.id) {
            incoming = HotPotatoCard.merge(local: existing, remote: incoming)
            if incoming.passGeneration == existing.passGeneration,
               incoming.status == existing.status,
               incoming.currentHolder.id == existing.currentHolder.id {
                if incoming.isIncomingCatch(for: me), asReceive, !isBlocked(incoming.previousHolder ?? incoming.creator) {
                    enqueueIncoming(incoming.id)
                }
                return
            }
        }
        if incoming.isExpired() && incoming.status != .exploded {
            incoming.explode()
        }
        let wasPaused = potato(card.id)?.isPaused
        let wasNewHold = incoming.isHeld(by: me) && !(potato(card.id)?.isHeld(by: me) ?? false)
        upsert(incoming)
        if let wasPaused, incoming.isPaused != wasPaused {
            pauseNotice = PauseNotice(
                cardID: incoming.id,
                callsign: incoming.callsign,
                byName: incoming.pausedBy?.displayName ?? incoming.history.last(where: { $0.action == .paused || $0.action == .resumed })?.player.displayName ?? "Someone",
                isPaused: incoming.isPaused
            )
            pauseEpoch += 1
        }
        incoming.uniquePlayers.filter { $0.id != me.id && !isBlocked($0) }.forEach(remember)
        let sender = incoming.previousHolder ?? incoming.creator
        if incoming.isIncomingCatch(for: me), asReceive || wasNewHold, !isBlocked(sender) {
            if wasNewHold { profile?.received += 1 }
            enqueueIncoming(incoming.id)
        }
        persist()
        if syncCloud {
            Task(priority: .userInitiated) { await push(incoming) }
        }
        pruneIncoming()
    }

    public func potato(_ id: UUID) -> HotPotatoCard? {
        potatoes.first { $0.id == id }
    }

    public func enqueueIncoming(_ id: UUID) {
        incomingQueue.removeAll { $0 == id }
        incomingQueue.append(id)
        pruneIncoming()
    }

    public func clearIncoming() {
        incomingQueue = []
    }

    public func beginThrowFromReceive() {
        guard let front = incomingCards.first else { return }
        beginThrow(front.id)
    }

    public func beginThrow(_ id: UUID) {
        guard potato(id)?.isHeld(by: me) == true else { return }
        pendingThrowID = id
        incomingQueue.removeAll { $0 == id }
    }

    public func consumePendingThrow() -> HotPotatoCard? {
        guard let id = pendingThrowID else { return nil }
        pendingThrowID = nil
        return potato(id)
    }

    public func deletePotato(_ id: UUID) {
        potatoes.removeAll { $0.id == id }
        incomingQueue.removeAll { $0 == id }
        persist()
        Task { await deleteRemote(id) }
    }

    /// Puts out a potato you lit and still hold, before anyone else has caught it.
    @discardableResult
    public func cancelOwnPotato(_ id: UUID) -> Bool {
        guard let card = potato(id) else { return false }
        guard card.creator.id == me.id else { return false }
        guard card.isHeld(by: me) else { return false }
        guard card.status != .exploded else { return false }
        guard card.passCount == 0 else { return false }
        potatoes.removeAll { $0.id == id }
        incomingQueue.removeAll { $0 == id }
        persist()
        Task { await deleteRemote(id) }
        return true
    }

    public func togglePause(_ id: UUID) throws {
        guard var card = potato(id) else { throw PotatoError.unknownPotato }
        guard card.isWatching(me) || card.isHeld(by: me) else { throw PotatoError.notHolder }
        if card.isPaused {
            try card.resume(by: me)
        } else {
            try card.pause(by: me)
        }
        upsert(card)
        pauseNotice = PauseNotice(
            cardID: card.id,
            callsign: card.callsign,
            byName: me.displayName,
            isPaused: card.isPaused
        )
        pauseEpoch += 1
        persist()
        Task(priority: .userInitiated) { await push(card) }
    }

    public func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        identity = PlayerRef(id: me.id, displayName: DisplayNameRules.sanitized(trimmed))
        if var profile {
            profile.identity = identity!
            self.profile = profile
        }
        persist()
    }

    public func refreshHeldFromCloud() async {
#if canImport(CloudKit)
        if let remote = try? await cloud?.fetchActive(for: me.id) {
            for card in remote {
                ingest(card, asReceive: card.isIncomingCatch(for: me))
            }
        }
        await refreshLiveFromCloud()
#endif
    }

    public func refreshLiveFromCloud() async {
#if canImport(CloudKit)
        let ids = Set(potatoes.filter { $0.status != .exploded }.map(\.id))
        for id in ids {
            if let remote = try? await cloud?.fetch(id: id) {
                ingest(
                    remote,
                    asReceive: remote.isIncomingCatch(for: me) || remote.status == .inFlight
                )
            }
        }
#endif
    }

    public func pullRemote(_ id: UUID) async -> HotPotatoCard? {
#if canImport(CloudKit)
        if let remote = try? await cloud?.fetch(id: id) {
            ingest(remote, asReceive: remote.status == .inFlight || remote.isIncomingCatch(for: me))
        }
#endif
        return potato(id)
    }

    private func pruneIncoming() {
        incomingQueue.removeAll { id in
            guard let card = potato(id) else { return true }
            return !card.isHeld(by: me) || card.status == .exploded
        }
    }

    public func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        mutate(&settings)
        persist()
    }

    public func dumpPicks(nearby: [PlayerRef]) -> [DumpPick] {
        PotatoBrain.dumpPicks(
            me: me,
            recent: visibleRecentPlayers,
            nearby: nearby,
            potatoes: potatoes,
            blocked: blockedPlayers
        )
    }

    public func repeatDumper(includeDismissed: Bool = false) -> PlayerRef? {
        let player = PotatoBrain.repeatDumper(onto: me, potatoes: potatoes, blocked: blockedPlayers)
        guard let player else { return nil }
        if !includeDismissed, dismissedNudgeIDs.contains(player.id) { return nil }
        return player
    }

    public func dismissNudge(for player: PlayerRef) {
        if !dismissedNudgeIDs.contains(player.id) {
            dismissedNudgeIDs.append(player.id)
        }
    }

    public var weeklyStory: String {
        PotatoBrain.weeklyStory(me: me, potatoes: potatoes, now: now)
    }

    public func shareResultText(_ card: HotPotatoCard) -> String {
        var lines = ["Cooked. — HAWT POTATO", PotatoBrain.explodeRecap(card: card), ""]
        if let note = card.note, !note.isEmpty {
            lines.append("“\(note)”")
            lines.append("")
        }
        for event in card.history where event.action != .passed {
            let mark = event.action == .exploded ? "💥" : "↓"
            lines.append("\(event.player.displayName) — \(event.remaining.hpClock) \(mark)")
        }
        lines.append("")
        let loser = card.explosion?.loser.displayName ?? card.currentHolder.displayName
        lines.append("\(loser.uppercased()) GOT COOKED")
        lines.append("\(card.passCount) PASSES")
        if card.gameMode == .mystery {
            lines.append("MYSTERY FUSE \(card.duration.hpClock)")
        } else {
            lines.append(card.duration.hpClock)
        }
        if card.gameMode != .classic {
            lines.append(card.gameMode.title)
        }
        return lines.joined(separator: "\n")
    }

    public func tick() {
        now = .now
        tickExplosions(at: now)
    }

    private func tickExplosions(at now: Date) {
        var changed = false
        for index in potatoes.indices {
            if potatoes[index].status != .exploded && potatoes[index].isExpired(at: now) {
                potatoes[index].explode(at: now)
                if potatoes[index].explosion?.loser.id == me.id {
                    profile?.explodedOnMe += 1
                }
                let exploded = potatoes[index]
                Task(priority: .userInitiated) { await push(exploded) }
                changed = true
            }
        }
        if changed {
            pruneIncoming()
            pruneHistory()
            persist()
        }
    }

    private func pruneHistory() {
        let exploded = potatoes.filter { $0.status == .exploded }
        guard exploded.count > 40 else { return }
        let keep = Set(exploded.sorted { ($0.explosion?.explodedAt ?? $0.expiresAt) > ($1.explosion?.explodedAt ?? $1.expiresAt) }.prefix(40).map(\.id))
        potatoes.removeAll { $0.status == .exploded && !keep.contains($0.id) }
    }

    private func upsert(_ card: HotPotatoCard) {
        if let index = potatoes.firstIndex(where: { $0.id == card.id }) {
            potatoes[index] = HotPotatoCard.merge(local: potatoes[index], remote: card)
        } else {
            potatoes.insert(card, at: 0)
        }
    }

    private func remember(_ player: PlayerRef) {
        guard player.id != me.id, !isBlocked(player) else { return }
        recentPlayers.removeAll { $0.id == player.id }
        recentPlayers.insert(player, at: 0)
        if recentPlayers.count > 24 { recentPlayers = Array(recentPlayers.prefix(24)) }
    }

    private func persist() {
        persistence.save(
            PersistedState(
                identity: identity,
                hasCompletedOnboarding: hasCompletedOnboarding,
                potatoes: potatoes,
                settings: settings,
                profile: profile,
                recentPlayers: recentPlayers,
                blockedPlayers: blockedPlayers
            )
        )
    }

    private func startClock() {
        timer?.invalidate()
        let interval = clockInterval()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.tick()
                let needed = self.clockInterval()
                if abs(needed - interval) > 0.05 {
                    self.startClock()
                }
            }
        }
    }

    private func clockInterval() -> TimeInterval {
        let live = holding + watching
        let left = live.map { $0.effectiveRemaining(at: now) }.min() ?? .greatestFiniteMagnitude
        if left <= 10 { return 0.25 }
        if left <= 30 { return 0.5 }
        return 1.0
    }

    private func refreshIdentityFromCloud() async {
#if canImport(CloudKit)
        if let name = await cloud?.currentUserRecordName(), let current = identity {
            identity = PlayerRef(id: name, displayName: current.displayName)
            persist()
        }
#endif
    }

    private func deleteRemote(_ id: UUID) async {
#if canImport(CloudKit)
        try? await cloud?.delete(id: id)
#endif
    }

    private func push(_ card: HotPotatoCard) async {
#if canImport(CloudKit)
        do {
            try await cloud?.save(card)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
#endif
    }
}
