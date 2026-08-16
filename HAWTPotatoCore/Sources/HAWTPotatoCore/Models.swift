import Foundation
import CoreLocation

public struct PlayerRef: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    public var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        if letters.isEmpty { return String(displayName.prefix(2)).uppercased() }
        return String(letters).uppercased()
    }

    public var contactPhone: String? {
        guard id.hasPrefix("contact:") else { return nil }
        let phone = String(id.dropFirst("contact:".count))
        return phone.isEmpty ? nil : phone
    }
}

public struct PauseNotice: Equatable, Sendable {
    public var cardID: UUID
    public var callsign: String
    public var byName: String
    public var isPaused: Bool

    public init(cardID: UUID, callsign: String, byName: String, isPaused: Bool) {
        self.cardID = cardID
        self.callsign = callsign
        self.byName = byName
        self.isPaused = isPaused
    }
}

public struct HandoffNotice: Equatable, Sendable {
    public var recipientName: String
    public var callsign: String
    public var at: Date

    public init(recipientName: String, callsign: String, at: Date) {
        self.recipientName = recipientName
        self.callsign = callsign
        self.at = at
    }
}

public enum PotatoStatus: String, Codable, Sendable {
    case active
    case inFlight
    case exploded
}

public enum GameMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case classic
    case mystery
    case suddenDeath

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classic: "CLASSIC"
        case .mystery: "MYSTERY"
        case .suddenDeath: "SUDDEN DEATH"
        }
    }

    public var subtitle: String {
        switch self {
        case .classic: "See the fuse. Throw before it hits zero."
        case .mystery: "Fuse is sealed. Nobody sees the clock."
        case .suddenDeath: "Eight seconds to throw after every catch."
        }
    }

    public var isMVP: Bool { true }

    public static let mysteryFuseRange: ClosedRange<Int> = 20...180
    public static let suddenDeathHold: TimeInterval = 8

    public static func rollMysteryDuration() -> TimeInterval {
        TimeInterval(Int.random(in: mysteryFuseRange))
    }
}

public enum LocationSharing: String, Codable, Sendable, CaseIterable, Identifiable {
    case hidden
    case approximate
    case precise

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hidden: "Hidden"
        case .approximate: "Approximate"
        case .precise: "Precise"
        }
    }
}

public enum PassAction: String, Codable, Sendable {
    case created
    case received
    case passed
    case claimed
    case exploded
    case paused
    case resumed
}

public struct LocationSnapshot: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var placeName: String
    public var sharing: LocationSharing
    public var recordedAt: Date

    public init(latitude: Double, longitude: Double, placeName: String, sharing: LocationSharing, recordedAt: Date = .now) {
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.sharing = sharing
        self.recordedAt = recordedAt
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var displayName: String {
        sharing == .hidden ? "Location Hidden" : placeName
    }
}

public struct PassEvent: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var player: PlayerRef
    public var at: Date
    public var remaining: TimeInterval
    public var location: LocationSnapshot?
    public var action: PassAction

    public init(
        id: UUID = UUID(),
        player: PlayerRef,
        at: Date = .now,
        remaining: TimeInterval,
        location: LocationSnapshot? = nil,
        action: PassAction
    ) {
        self.id = id
        self.player = player
        self.at = at
        self.remaining = remaining
        self.location = location
        self.action = action
    }
}

public struct ExplosionResult: Codable, Hashable, Sendable {
    public var loser: PlayerRef
    public var explodedAt: Date
    public var passCount: Int
    public var playerCount: Int

    public init(loser: PlayerRef, explodedAt: Date = .now, passCount: Int, playerCount: Int) {
        self.loser = loser
        self.explodedAt = explodedAt
        self.passCount = passCount
        self.playerCount = playerCount
    }
}

public struct DurationPreset: Identifiable, Hashable, Sendable {
    public var id: String { title }
    public var title: String
    public var seconds: TimeInterval

    public static let all: [DurationPreset] = [
        .init(title: "15 sec", seconds: 15),
        .init(title: "30 sec", seconds: 30),
        .init(title: "45 sec", seconds: 45),
        .init(title: "1 min", seconds: 60),
        .init(title: "2 min", seconds: 120),
        .init(title: "5 min", seconds: 300),
        .init(title: "10 min", seconds: 600),
        .init(title: "30 min", seconds: 1_800),
        .init(title: "1 hour", seconds: 3_600)
    ]

    public init(title: String, seconds: TimeInterval) {
        self.title = title
        self.seconds = seconds
    }
}

public struct HotPotatoCard: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var gameID: UUID
    public var creator: PlayerRef
    public var createdAt: Date
    public var expiresAt: Date
    public var duration: TimeInterval
    public var currentHolder: PlayerRef
    public var previousHolder: PlayerRef?
    public var status: PotatoStatus
    public var passCount: Int
    public var history: [PassEvent]
    public var locationSharing: LocationSharing
    public var lastLocation: LocationSnapshot?
    public var theme: String
    public var explosion: ExplosionResult?
    public var watchers: [PlayerRef]
    public var gameMode: GameMode
    public var offeredToGroup: Bool
    public var passGeneration: Int
    public var receivedAt: Date?
    public var mustThrowBy: Date?
    public var nickname: String?
    public var note: String?
    public var pausedAt: Date?
    public var pausedBy: PlayerRef?
    public var remainingWhenPaused: TimeInterval?
    public var throwWindowWhenPaused: TimeInterval?

    public init(
        id: UUID = UUID(),
        gameID: UUID = UUID(),
        creator: PlayerRef,
        createdAt: Date = .now,
        expiresAt: Date,
        duration: TimeInterval,
        currentHolder: PlayerRef,
        previousHolder: PlayerRef? = nil,
        status: PotatoStatus = .active,
        passCount: Int = 0,
        history: [PassEvent] = [],
        locationSharing: LocationSharing = .hidden,
        lastLocation: LocationSnapshot? = nil,
        theme: String = "classic",
        explosion: ExplosionResult? = nil,
        watchers: [PlayerRef] = [],
        gameMode: GameMode = .classic,
        offeredToGroup: Bool = false,
        passGeneration: Int = 0,
        receivedAt: Date? = nil,
        mustThrowBy: Date? = nil,
        nickname: String? = nil,
        note: String? = nil,
        pausedAt: Date? = nil,
        pausedBy: PlayerRef? = nil,
        remainingWhenPaused: TimeInterval? = nil,
        throwWindowWhenPaused: TimeInterval? = nil
    ) {
        self.id = id
        self.gameID = gameID
        self.creator = creator
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.duration = duration
        self.currentHolder = currentHolder
        self.previousHolder = previousHolder
        self.status = status
        self.passCount = passCount
        self.history = history
        self.locationSharing = locationSharing
        self.lastLocation = lastLocation
        self.theme = theme
        self.explosion = explosion
        self.watchers = watchers
        self.gameMode = gameMode
        self.offeredToGroup = offeredToGroup
        self.passGeneration = passGeneration
        self.receivedAt = receivedAt
        self.mustThrowBy = mustThrowBy
        self.nickname = nickname
        self.note = note
        self.pausedAt = pausedAt
        self.pausedBy = pausedBy
        self.remainingWhenPaused = remainingWhenPaused
        self.throwWindowWhenPaused = throwWindowWhenPaused
    }

    public var isPaused: Bool {
        pausedAt != nil && status != .exploded
    }

    public var callsign: String {
        if let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nickname
        }
        return "Potato #\(shortCode)"
    }

    public var shortCode: String {
        String(id.uuidString.replacingOccurrences(of: "-", with: "").prefix(4)).uppercased()
    }

    public func remaining(at now: Date = .now) -> TimeInterval {
        if isPaused, let frozen = remainingWhenPaused {
            return frozen
        }
        return expiresAt.timeIntervalSince(now)
    }

    public func throwWindowRemaining(at now: Date = .now) -> TimeInterval? {
        if isPaused { return throwWindowWhenPaused }
        guard gameMode == .suddenDeath, status != .exploded, let mustThrowBy else { return nil }
        return mustThrowBy.timeIntervalSince(now)
    }

    public func lethalDeadline(at now: Date = .now) -> Date {
        if gameMode == .suddenDeath, let mustThrowBy {
            return min(expiresAt, mustThrowBy)
        }
        return expiresAt
    }

    public func effectiveRemaining(at now: Date = .now) -> TimeInterval {
        lethalDeadline(at: now).timeIntervalSince(now)
    }

    public func isExpired(at now: Date = .now) -> Bool {
        if isPaused { return false }
        return now >= lethalDeadline(at: now)
    }

    public var hidesClock: Bool {
        status != .exploded && gameMode == .mystery
    }

    public var revealsPassTimes: Bool {
        status == .exploded || gameMode != .mystery
    }

    public func clockText(at now: Date = .now, isHolder: Bool) -> String {
        if status == .exploded {
            return gameMode == .mystery ? duration.hpClock : "00:00"
        }
        if isPaused {
            return hidesClock ? "PAUSED" : "⏸ \(max(0, remaining(at: now)).hpClock)"
        }
        if hidesClock {
            return PotatoBrain.mysteryMood(card: self, now: now)
        }
        if gameMode == .suddenDeath, isHolder, let window = throwWindowRemaining(at: now) {
            return max(0, window).hpClock
        }
        return max(0, remaining(at: now)).hpClock
    }

    public func modeCaption(at now: Date = .now, isHolder: Bool) -> String? {
        guard status != .exploded else {
            return gameMode == .mystery ? "FUSE WAS \(duration.hpClock)" : nil
        }
        if isPaused {
            return "PAUSED BY \(pausedBy?.displayName.uppercased() ?? "SOMEONE") · EVERYONE CAN SEE THIS"
        }
        switch gameMode {
        case .classic:
            return nil
        case .mystery:
            return titleForMode
        case .suddenDeath:
            if isHolder {
                return "THROW OR DIE · FUSE \(max(0, remaining(at: now)).hpClock)"
            }
            return "SUDDEN DEATH"
        }
    }

    public var titleForMode: String { gameMode.title }

    public func isHeld(by player: PlayerRef) -> Bool {
        status != .exploded && currentHolder.id == player.id
    }

    public func isIncomingCatch(for player: PlayerRef) -> Bool {
        guard isHeld(by: player), status != .exploded else { return false }
        if let previous = previousHolder {
            return previous.id != player.id
        }
        return creator.id != player.id
    }

    public func isWatching(_ player: PlayerRef) -> Bool {
        creator.id == player.id
            || watchers.contains { $0.id == player.id }
            || history.contains { $0.player.id == player.id }
    }

    public var uniquePlayers: [PlayerRef] {
        var seen: [String: PlayerRef] = [:]
        for event in history { seen[event.player.id] = event.player }
        seen[creator.id] = creator
        seen[currentHolder.id] = currentHolder
        return Array(seen.values)
    }

    public func heat(at now: Date = .now) -> PotatoHeat {
        let fuse = fuseHeat(at: now)
        guard gameMode == .suddenDeath, let window = throwWindowRemaining(at: now) else { return fuse }
        let windowHeat: PotatoHeat
        if window <= 2 { windowHeat = .finalCountdown }
        else if window <= 3.5 { windowHeat = .critical }
        else if window <= 5.5 { windowHeat = .hot }
        else { windowHeat = .warming }
        return max(fuse, windowHeat)
    }

    private func fuseHeat(at now: Date) -> PotatoHeat {
        let left = remaining(at: now)
        if left <= 5 { return .finalCountdown }
        if left <= 10 { return .critical }
        let ratio = max(0, min(1, left / max(duration, 1)))
        if ratio <= 0.25 { return .hot }
        if ratio <= 0.55 { return .warming }
        return .normal
    }

    public var deepLink: URL {
        URL(string: "\(ProductCanon.urlScheme)://potato/\(id.uuidString)")!
    }

    public var webLink: URL {
        URL(string: "https://\(ProductCanon.appClipHost)/p/\(id.uuidString)")!
    }

    public static func light(
        by creator: PlayerRef,
        duration: TimeInterval,
        locationSharing: LocationSharing,
        location: LocationSnapshot?,
        gameMode: GameMode = .classic,
        theme: String = PotatoSkin.classic.rawValue,
        nickname: String? = nil,
        note: String? = nil,
        now: Date = .now
    ) -> HotPotatoCard {
        let fuse = gameMode == .mystery ? GameMode.rollMysteryDuration() : duration
        let expires = now.addingTimeInterval(fuse)
        var card = HotPotatoCard(
            creator: creator,
            createdAt: now,
            expiresAt: expires,
            duration: fuse,
            currentHolder: creator,
            locationSharing: locationSharing,
            lastLocation: location,
            theme: theme,
            watchers: [creator],
            gameMode: gameMode,
            receivedAt: now,
            nickname: nickname,
            note: note
        )
        card.armHoldWindow(at: now)
        card.history = [
            PassEvent(player: creator, at: now, remaining: fuse, location: location, action: .created)
        ]
        return card
    }

    public mutating func throwTo(_ target: PlayerRef, location: LocationSnapshot?, now: Date = .now) throws {
        try Self.ensureLive(self, now: now)
        guard currentHolder.id != target.id else {
            throw PotatoError.cannotThrowToSelf
        }
        previousHolder = currentHolder
        currentHolder = target
        passCount += 1
        passGeneration += 1
        status = .active
        offeredToGroup = false
        lastLocation = location ?? lastLocation
        addWatcher(target)
        armHoldWindow(at: now)
        history.append(PassEvent(player: previousHolder!, at: now, remaining: remaining(at: now), location: location, action: .passed))
        history.append(PassEvent(player: target, at: now, remaining: remaining(at: now), location: location, action: .received))
    }

    public mutating func offerToGroup(from holder: PlayerRef, now: Date = .now) throws {
        try Self.ensureLive(self, now: now)
        guard currentHolder.id == holder.id else { throw PotatoError.notHolder }
        status = .inFlight
        offeredToGroup = true
        passGeneration += 1
        mustThrowBy = nil
        history.append(PassEvent(player: holder, at: now, remaining: remaining(at: now), location: lastLocation, action: .passed))
    }

    public mutating func claim(by player: PlayerRef, location: LocationSnapshot?, now: Date = .now) throws {
        try Self.ensureLive(self, now: now)
        guard status == .inFlight else { throw PotatoError.notOffered }
        guard player.id != currentHolder.id else { throw PotatoError.cannotThrowToSelf }
        previousHolder = currentHolder
        currentHolder = player
        passCount += 1
        passGeneration += 1
        status = .active
        offeredToGroup = false
        lastLocation = location ?? lastLocation
        addWatcher(player)
        armHoldWindow(at: now)
        history.append(PassEvent(player: player, at: now, remaining: remaining(at: now), location: location, action: .claimed))
    }

    public mutating func pause(by player: PlayerRef, now: Date = .now) throws {
        try Self.ensureLive(self, now: now)
        guard !isPaused else { return }
        let left = max(0, remaining(at: now))
        remainingWhenPaused = left
        throwWindowWhenPaused = throwWindowRemaining(at: now).map { max(0, $0) }
        pausedAt = now
        pausedBy = player
        passGeneration += 1
        history.append(PassEvent(player: player, at: now, remaining: left, location: lastLocation, action: .paused))
    }

    public mutating func resume(by player: PlayerRef, now: Date = .now) throws {
        guard status != .exploded else { throw PotatoError.alreadyExploded }
        guard isPaused else { return }
        let left = remainingWhenPaused ?? max(0, remaining(at: now))
        expiresAt = now.addingTimeInterval(left)
        if let window = throwWindowWhenPaused {
            mustThrowBy = now.addingTimeInterval(window)
        }
        remainingWhenPaused = nil
        throwWindowWhenPaused = nil
        pausedAt = nil
        pausedBy = nil
        passGeneration += 1
        history.append(PassEvent(player: player, at: now, remaining: left, location: lastLocation, action: .resumed))
    }

    public mutating func explode(at now: Date = .now) {
        guard status != .exploded else { return }
        status = .exploded
        let loser = currentHolder
        explosion = ExplosionResult(
            loser: loser,
            explodedAt: now,
            passCount: passCount,
            playerCount: uniquePlayers.count
        )
        history.append(PassEvent(player: loser, at: now, remaining: 0, location: lastLocation, action: .exploded))
    }

    public mutating func addWatcher(_ player: PlayerRef) {
        if !watchers.contains(where: { $0.id == player.id }) {
            watchers.append(player)
        }
    }

    public mutating func armHoldWindow(at now: Date = .now) {
        receivedAt = now
        guard gameMode == .suddenDeath, status != .exploded else {
            mustThrowBy = nil
            return
        }
        mustThrowBy = min(now.addingTimeInterval(GameMode.suddenDeathHold), expiresAt)
    }

    public static func merge(local: HotPotatoCard, remote: HotPotatoCard) -> HotPotatoCard {
        if remote.passGeneration != local.passGeneration {
            return remote.passGeneration > local.passGeneration ? remote : local
        }
        if local.status == .exploded { return local }
        if remote.status == .exploded { return remote }
        return remote
    }

    private static func ensureLive(_ card: HotPotatoCard, now: Date) throws {
        if card.isPaused {
            throw PotatoError.paused
        }
        if card.status == .exploded || card.isExpired(at: now) {
            throw PotatoError.alreadyExploded
        }
    }
}

public enum PotatoError: LocalizedError, Equatable, Sendable {
    case alreadyExploded
    case notHolder
    case notOffered
    case cannotThrowToSelf
    case duplicateHolder
    case unknownPotato
    case paused

    public var errorDescription: String? {
        switch self {
        case .alreadyExploded: "Too late. This potato already cooked someone."
        case .notHolder: "You don't have this potato."
        case .notOffered: "This potato isn't in the air."
        case .cannotThrowToSelf: "Throw it to someone else."
        case .duplicateHolder: "One potato. One holder."
        case .unknownPotato: "Can't find that potato."
        case .paused: "This potato is paused. Resume it to keep playing."
        }
    }
}

public struct AppSettings: Codable, Hashable, Sendable {
    public var soundEffects = true
    public var haptics = true
    public var countdownSounds = true
    public var notifyReceived = true
    public var notifyWarnings = true
    public var notifyMovement = true
    public var notifyExplosion = true
    public var notifyResults = true
    public var locationSharing: LocationSharing = .hidden
    public var appearance: AppearanceMode = .system

    public init() {}

    enum CodingKeys: String, CodingKey {
        case soundEffects, haptics, countdownSounds
        case notifyReceived, notifyWarnings, notifyMovement, notifyExplosion, notifyResults
        case locationSharing, appearance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        soundEffects = try container.decodeIfPresent(Bool.self, forKey: .soundEffects) ?? true
        haptics = try container.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        countdownSounds = try container.decodeIfPresent(Bool.self, forKey: .countdownSounds) ?? true
        notifyReceived = try container.decodeIfPresent(Bool.self, forKey: .notifyReceived) ?? true
        notifyWarnings = try container.decodeIfPresent(Bool.self, forKey: .notifyWarnings) ?? true
        notifyMovement = try container.decodeIfPresent(Bool.self, forKey: .notifyMovement) ?? true
        notifyExplosion = try container.decodeIfPresent(Bool.self, forKey: .notifyExplosion) ?? true
        notifyResults = try container.decodeIfPresent(Bool.self, forKey: .notifyResults) ?? true
        locationSharing = try container.decodeIfPresent(LocationSharing.self, forKey: .locationSharing) ?? .hidden
        appearance = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(soundEffects, forKey: .soundEffects)
        try container.encode(haptics, forKey: .haptics)
        try container.encode(countdownSounds, forKey: .countdownSounds)
        try container.encode(notifyReceived, forKey: .notifyReceived)
        try container.encode(notifyWarnings, forKey: .notifyWarnings)
        try container.encode(notifyMovement, forKey: .notifyMovement)
        try container.encode(notifyExplosion, forKey: .notifyExplosion)
        try container.encode(notifyResults, forKey: .notifyResults)
        try container.encode(locationSharing, forKey: .locationSharing)
        try container.encode(appearance, forKey: .appearance)
    }
}

public struct PlayerProfile: Codable, Hashable, Sendable {
    public var identity: PlayerRef
    public var received = 0
    public var passed = 0
    public var explodedOnMe = 0
    public var fastestPass: TimeInterval?
    public var longestSafeHold: TimeInterval?
    public var totalThrows = 0

    public init(identity: PlayerRef) {
        self.identity = identity
    }

    public var survivalRate: Double {
        guard received > 0 else { return 1 }
        return Double(passed) / Double(received)
    }
}
