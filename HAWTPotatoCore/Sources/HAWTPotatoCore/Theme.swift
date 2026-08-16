import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum AppearanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case dark
    case light

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

public enum HPColor {
    public static let potatoOrange = Color(red: 1, green: 122 / 255, blue: 0)
    public static let flameYellow = Color(red: 1, green: 196 / 255, blue: 0)
    public static let criticalRed = Color(red: 1, green: 59 / 255, blue: 48 / 255)
    public static let secondaryGray = Color.secondary

    public static let cream = Color(red: 250 / 255, green: 243 / 255, blue: 228 / 255)
    public static let tan = Color(red: 232 / 255, green: 210 / 255, blue: 176 / 255)
    public static let lightBrown = Color(red: 176 / 255, green: 132 / 255, blue: 86 / 255)
    public static let darkBrown = Color(red: 62 / 255, green: 38 / 255, blue: 22 / 255)

    public static let nearBlack = Color.hp(light: cream, dark: Color(red: 5 / 255, green: 5 / 255, blue: 5 / 255))
    public static let canvas = nearBlack
    public static let ink = Color.hp(light: darkBrown, dark: .white)
    public static let muted = Color.hp(light: darkBrown.opacity(0.62), dark: .white.opacity(0.62))
    public static let faint = Color.hp(light: darkBrown.opacity(0.42), dark: .white.opacity(0.45))
    public static let card = Color.hp(light: lightBrown.opacity(0.16), dark: .white.opacity(0.07))
}

public enum HPFont {
    public static func title(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    public static func timer(_ size: CGFloat = 56) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }

    public static func label() -> Font {
        .system(.subheadline, design: .default).weight(.medium)
    }

    public static func name() -> Font {
        .system(.title2, design: .default).weight(.bold)
    }

    public static func body() -> Font {
        .system(.body, design: .default)
    }

    public static func action() -> Font {
        .system(.title3, design: .default).weight(.bold)
    }
}

public enum PotatoHeat: String, Sendable, Comparable {
    case normal
    case warming
    case hot
    case critical
    case finalCountdown

    public var accessibilityLabel: String {
        switch self {
        case .normal: "Warm"
        case .warming: "Getting hot"
        case .hot: "Hot"
        case .critical: "Critical"
        case .finalCountdown: "Final seconds"
        }
    }

    private var rank: Int {
        switch self {
        case .normal: 0
        case .warming: 1
        case .hot: 2
        case .critical: 3
        case .finalCountdown: 4
        }
    }

    public static func < (lhs: PotatoHeat, rhs: PotatoHeat) -> Bool {
        lhs.rank < rhs.rank
    }
}

public extension TimeInterval {
    var hpClock: String {
        let clamped = max(0, self)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension Color {
    static func hp(light: Color, dark: Color) -> Color {
#if os(watchOS)
        dark
#elseif canImport(UIKit)
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
#else
        dark
#endif
    }
}
