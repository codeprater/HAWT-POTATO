import Foundation

public struct PersistedState: Codable, Sendable {
    public var identity: PlayerRef?
    public var hasCompletedOnboarding: Bool
    public var potatoes: [HotPotatoCard]
    public var settings: AppSettings
    public var profile: PlayerProfile?
    public var recentPlayers: [PlayerRef]
    public var blockedPlayers: [PlayerRef]

    public init(
        identity: PlayerRef? = nil,
        hasCompletedOnboarding: Bool = false,
        potatoes: [HotPotatoCard] = [],
        settings: AppSettings = AppSettings(),
        profile: PlayerProfile? = nil,
        recentPlayers: [PlayerRef] = [],
        blockedPlayers: [PlayerRef] = []
    ) {
        self.identity = identity
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.potatoes = potatoes
        self.settings = settings
        self.profile = profile
        self.recentPlayers = recentPlayers
        self.blockedPlayers = blockedPlayers
    }

    enum CodingKeys: String, CodingKey {
        case identity, hasCompletedOnboarding, potatoes, settings, profile, recentPlayers, blockedPlayers, blockedPlayerIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identity = try container.decodeIfPresent(PlayerRef.self, forKey: .identity)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        potatoes = try container.decodeIfPresent([HotPotatoCard].self, forKey: .potatoes) ?? []
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        profile = try container.decodeIfPresent(PlayerProfile.self, forKey: .profile)
        recentPlayers = try container.decodeIfPresent([PlayerRef].self, forKey: .recentPlayers) ?? []
        if let players = try container.decodeIfPresent([PlayerRef].self, forKey: .blockedPlayers) {
            blockedPlayers = players
        } else {
            let ids = try container.decodeIfPresent([String].self, forKey: .blockedPlayerIDs) ?? []
            blockedPlayers = ids.map { PlayerRef(id: $0, displayName: "Blocked player") }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(identity, forKey: .identity)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(potatoes, forKey: .potatoes)
        try container.encode(settings, forKey: .settings)
        try container.encodeIfPresent(profile, forKey: .profile)
        try container.encode(recentPlayers, forKey: .recentPlayers)
        try container.encode(blockedPlayers, forKey: .blockedPlayers)
    }
}

public struct LocalPersistence: Sendable {
    private let filename = "hawt-potato-state.json"

    public init() {}

    public func url() -> URL {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ProductCanon.appGroupIdentifier
        ) {
            return container.appending(path: filename)
        }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "HAWT POTATO", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: filename)
    }

    public func load() -> PersistedState {
        let file = url()
        guard let data = try? Data(contentsOf: file) else { return PersistedState() }
        return (try? JSONDecoder().decode(PersistedState.self, from: data)) ?? PersistedState()
    }

    public func save(_ state: PersistedState) {
        let file = url()
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: file, options: [.atomic])
    }
}

public struct WatchSnapshot: Codable, Sendable {
    public var holding: [HotPotatoCard]
    public var watching: [HotPotatoCard]
    public var history: [HotPotatoCard]
    public var me: PlayerRef
    public var now: Date

    public init(
        holding: [HotPotatoCard],
        watching: [HotPotatoCard],
        history: [HotPotatoCard],
        me: PlayerRef,
        now: Date
    ) {
        self.holding = holding
        self.watching = watching
        self.history = history
        self.me = me
        self.now = now
    }
}

public enum PotatoPayload {
    public static func data(from card: HotPotatoCard) throws -> Data {
        try JSONEncoder().encode(card)
    }

    public static func card(from data: Data) throws -> HotPotatoCard {
        try JSONDecoder().decode(HotPotatoCard.self, from: data)
    }

    public static func writeTemporaryFile(for card: HotPotatoCard) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "HAWT-POTATO-\(card.shortCode).\(ProductCanon.fileExtension)")
        try data(from: card).write(to: url, options: [.atomic])
        return url
    }
}
