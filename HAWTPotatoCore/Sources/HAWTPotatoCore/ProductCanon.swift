import Foundation

/// HAWT POTATO 2.0 product canon.
///
/// **THE POTATO IS THE GAME.**
/// Not the lobby. Not the app. Not the map. Not the player profile.
/// Every feature must make receiving, carrying, throwing, watching, or remembering the potato more fun.
public enum ProductCanon {
    public static let displayName = "HAWT POTATO"
    public static let bundleIdentifier = "com.courtneyprater.HawtPotato"
    public static let appGroupIdentifier = "group.com.courtneyprater.HawtPotato"
    public static let cloudKitContainer = "iCloud.com.courtneyprater.HawtPotato"
    public static let nearbyServiceType = "hawt-potato"
    public static let urlScheme = "hawtpotato"
    public static let appClipHost = "hawtpotato.app"
    public static let appStoreURL = URL(string: "https://apps.apple.com/app/hawt-potato")!
    public static let marketingURL = URL(string: "https://hawtpotato.app")!
    public static let privacyURL = URL(string: "https://hawtpotato.app/privacy")!
    public static let termsURL = URL(string: "https://hawtpotato.app/terms")!
    public static let supportEmail = "support@hawtpotato.app"
    public static let copyrightLine = "2026 Courtney & Kourtney Prater"
    public static let minimumAge = 13

    public static func supportMailURL() -> URL {
        mailURL(subject: "HAWT POTATO support", body: "")
    }

    public static func reportMailURL(player: PlayerRef, reporter: PlayerRef, harassmentLikely: Bool = false) -> URL {
        var body = """
            I want to report this player.

            Display name: \(player.displayName)
            Player ID: \(player.id)
            Reported by: \(reporter.displayName) (\(reporter.id))

            What happened:


            """
        if harassmentLikely {
            body += "Flag: this player has been dumping on the reporter over and over.\n"
        }
        return mailURL(
            subject: "HAWT POTATO player report",
            body: body
        )
    }

    private static func mailURL(subject: String, body: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url ?? URL(string: "mailto:\(supportEmail)")!
    }
    public static let fileExtension = "hawtpotato"
    public static let exportedTypeIdentifier = "com.courtneyprater.hawtpotato"

    public static let voice = Voice()

    public struct Voice: Sendable {
        public let light = "LIGHT THE POTATO"
        public let passIt = "PASS IT"
        public let throwIt = "THROW"
        public let youGotCooked = "YOU GOT COOKED"
        public let theyGotCooked = "GOT COOKED"
        public let theyAreCooked = "THEY ARE COOKED!"
        public let startThrowing = "START THROWING"
        public let startAPotato = "START A POTATO"
        public let youHaveIt = "YOU HAVE IT"
        public let youreHolding = "YOU'RE HOLDING"
        public let currentlyWith = "CURRENTLY WITH"
        public let safe = "SAFE!"
        public let findMyPotato = "FIND MY POTATO"
        public let installToCatchIt = "INSTALL TO CATCH IT"
        public let stillCooking = "IT'S STILL COOKING"
        public let throwOrDie = "THROW OR DIE"
    }
}

public enum PotatoLink {
    public static func id(from url: URL) -> UUID? {
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme == ProductCanon.urlScheme, parts.count >= 2 {
            return UUID(uuidString: parts[1])
        }
        if url.host == ProductCanon.appClipHost || url.host == "www.\(ProductCanon.appClipHost)" {
            return parts.last.flatMap { UUID(uuidString: $0) }
        }
        return UUID(uuidString: url.lastPathComponent)
    }
}
