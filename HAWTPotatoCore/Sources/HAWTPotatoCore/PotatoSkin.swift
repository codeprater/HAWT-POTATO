import SwiftUI

public enum PotatoSkin: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic
    case classicRing = "classic-ring"
    case day
    case dayRing = "day-ring"
    case panic
    case maniacal
    case shocked
    case distressed
    case wink
    case dazed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classic: "Classic"
        case .classicRing: "Ring of Fire"
        case .day: "White Heat"
        case .dayRing: "Halo"
        case .panic: "Panic"
        case .maniacal: "Maniacal"
        case .shocked: "Shocked"
        case .distressed: "Distressed"
        case .wink: "Wink"
        case .dazed: "Dazed"
        }
    }

    public var image: Image {
        Image(rawValue, bundle: .module)
    }

    var hasRing: Bool {
        self == .classicRing || self == .dayRing
    }
}

public struct PotatoArt: View {
    public var skin: PotatoSkin
    public var exploded: Bool = false
    public var size: CGFloat = 120
    public var live: Bool = true
    public var heat: PotatoHeat = .normal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(skin: PotatoSkin, exploded: Bool = false, size: CGFloat = 120, live: Bool = true, heat: PotatoHeat = .normal) {
        self.skin = skin
        self.exploded = exploded
        self.size = size
        self.live = live
        self.heat = heat
    }

    public var body: some View {
        Group {
            if live && !exploded && !reduceMotion && size >= 40 {
                TimelineView(.animation(minimumInterval: size >= 90 ? 1.0 / 12.0 : 1.0 / 8.0, paused: false)) { timeline in
                    framed(date: timeline.date)
                }
            } else {
                framed(date: nil)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(exploded ? "Exploded \(skin.title) potato" : "\(skin.title) potato")
        .accessibilityAddTraits(.isImage)
    }

    private func framed(date: Date?) -> some View {
        let motion = LivePotatoMotion.pose(skin: skin, date: date, size: size)
        return ZStack {
            if skin.hasRing {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [HPColor.flameYellow, HPColor.potatoOrange, HPColor.criticalRed, HPColor.flameYellow],
                            center: .center
                        ),
                        lineWidth: max(3, size * 0.055)
                    )
                    .frame(width: size * 0.94, height: size * 0.94)
                    .rotationEffect(.degrees(motion.ringSpin))
                    .opacity(0.55 + motion.glow)
                    .blur(radius: 0.4)
            }

            skin.image
                .resizable()
                .scaledToFit()
                .scaleEffect(x: motion.scaleX, y: motion.scaleY)
                .rotationEffect(.degrees(motion.rotation))
                .offset(x: motion.dx, y: motion.dy)
                .opacity(exploded ? 0.35 : 1)

            if live && !exploded && !reduceMotion {
                sparks(motion: motion, date: date ?? .now)
            }

            if exploded {
                Text("💥")
                    .font(.system(size: size * 0.55))
            }
        }
    }

    private func sparks(motion: LivePotatoMotion, date: Date) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let count: Int
        let reach: CGFloat
        switch heat {
        case .normal:
            count = 3
            reach = 0.26
        case .warming:
            count = 4
            reach = 0.3
        case .hot:
            count = 6
            reach = 0.36
        case .critical:
            count = 8
            reach = 0.42
        case .finalCountdown:
            count = 11
            reach = 0.5
        }
        let sparkSize = max(2, size * (heat >= .hot ? 0.045 : 0.035))
        let hotColor = heat >= .critical ? HPColor.criticalRed : HPColor.potatoOrange
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                sparkDot(index: index, time: t, motion: motion, reach: reach, size: sparkSize, alt: hotColor)
            }
        }
        .allowsHitTesting(false)
    }

    private func sparkDot(index: Int, time: Double, motion: LivePotatoMotion, reach: CGFloat, size sparkSize: CGFloat, alt: Color) -> some View {
        let spin = time * (1.6 + Double(index) * 0.18) + Double(index)
        return Circle()
            .fill(index.isMultiple(of: 2) ? HPColor.flameYellow : alt)
            .frame(width: sparkSize, height: sparkSize)
            .offset(
                x: cos(spin) * size * (reach + motion.glow * 0.12),
                y: sin(spin * 1.3) * size * (reach + 0.04) - size * 0.1
            )
            .opacity(0.4 + 0.5 * (0.5 + 0.5 * sin(spin)))
    }
}

struct LivePotatoMotion {
    var dx: CGFloat
    var dy: CGFloat
    var rotation: Double
    var scaleX: CGFloat
    var scaleY: CGFloat
    var ringSpin: Double
    var glow: Double

    static func pose(skin: PotatoSkin, date: Date?, size: CGFloat) -> LivePotatoMotion {
        guard let date else {
            return LivePotatoMotion(dx: 0, dy: 0, rotation: 0, scaleX: 1, scaleY: 1, ringSpin: 0, glow: 0.2)
        }
        let period = loop(for: skin)
        let seed = Double(abs(skin.rawValue.hashValue % 97)) / 97.0
        let elapsed = date.timeIntervalSinceReferenceDate + seed * period
        let phase = (elapsed.truncatingRemainder(dividingBy: period)) / period
        let wave = sin(phase * .pi * 2)
        let wave2 = sin(phase * .pi * 4)
        let bounce = size * 0.04

        switch skin {
        case .classic:
            return LivePotatoMotion(
                dx: wave * size * 0.012,
                dy: wave * bounce,
                rotation: wave * 3.5,
                scaleX: 1 + wave2 * 0.03,
                scaleY: 1 + wave * 0.045,
                ringSpin: 0,
                glow: 0.25 + 0.2 * (0.5 + 0.5 * wave)
            )
        case .classicRing:
            return LivePotatoMotion(
                dx: wave * size * 0.01,
                dy: wave * bounce * 0.8,
                rotation: wave * 2.5,
                scaleX: 1.02,
                scaleY: 1 + wave * 0.03,
                ringSpin: phase * 360,
                glow: 0.4 + 0.3 * (0.5 + 0.5 * wave)
            )
        case .day:
            return LivePotatoMotion(
                dx: 0,
                dy: wave * bounce * 0.7,
                rotation: wave * 2,
                scaleX: 1 + wave * 0.02,
                scaleY: 1 + wave * 0.02,
                ringSpin: 0,
                glow: 0.2 + 0.15 * (0.5 + 0.5 * wave)
            )
        case .dayRing:
            return LivePotatoMotion(
                dx: wave * size * 0.008,
                dy: sin(phase * .pi * 2 + 0.6) * bounce * 0.6,
                rotation: wave * 1.8,
                scaleX: 1 + wave2 * 0.025,
                scaleY: 1 + wave2 * 0.025,
                ringSpin: -phase * 360,
                glow: 0.45 + 0.35 * (0.5 + 0.5 * wave)
            )
        case .panic:
            return LivePotatoMotion(
                dx: wave * size * 0.055,
                dy: wave2 * bounce * 0.5,
                rotation: wave * 9,
                scaleX: 1 + abs(wave) * 0.04,
                scaleY: 1 - abs(wave) * 0.03,
                ringSpin: 0,
                glow: 0.55
            )
        case .maniacal:
            return LivePotatoMotion(
                dx: wave2 * size * 0.02,
                dy: abs(wave) * -bounce * 0.6,
                rotation: wave * 14,
                scaleX: 1 + abs(wave) * 0.07,
                scaleY: 1 + abs(wave) * 0.07,
                ringSpin: 0,
                glow: 0.5 + 0.3 * abs(wave)
            )
        case .shocked:
            let hop = abs(sin(phase * .pi))
            return LivePotatoMotion(
                dx: 0,
                dy: -hop * bounce * 1.4,
                rotation: wave * 2,
                scaleX: 1 - hop * 0.04,
                scaleY: 1 + hop * 0.12,
                ringSpin: 0,
                glow: 0.3 + hop * 0.4
            )
        case .distressed:
            return LivePotatoMotion(
                dx: wave2 * size * 0.03,
                dy: wave * bounce * 0.35,
                rotation: wave2 * 4,
                scaleX: 1 + abs(wave2) * 0.02,
                scaleY: 1 - abs(wave) * 0.05,
                ringSpin: 0,
                glow: 0.35
            )
        case .wink:
            let wink = phase > 0.68 && phase < 0.8
            return LivePotatoMotion(
                dx: 0,
                dy: wave * bounce * 0.45,
                rotation: wink ? 9 : wave * 2.5,
                scaleX: wink ? 1.06 : 1,
                scaleY: wink ? 0.86 : 1 + wave * 0.02,
                ringSpin: 0,
                glow: wink ? 0.55 : 0.22
            )
        case .dazed:
            return LivePotatoMotion(
                dx: sin(phase * .pi * 2) * size * 0.045,
                dy: cos(phase * .pi * 2) * bounce * 0.9,
                rotation: wave * 11,
                scaleX: 1.02,
                scaleY: 1.02,
                ringSpin: 0,
                glow: 0.28 + 0.2 * (0.5 + 0.5 * wave)
            )
        }
    }

    private static func loop(for skin: PotatoSkin) -> Double {
        switch skin {
        case .classic: 0.62
        case .classicRing: 0.9
        case .day: 1.35
        case .dayRing: 1.15
        case .panic: 0.16
        case .maniacal: 0.38
        case .shocked: 0.72
        case .distressed: 0.22
        case .wink: 1.55
        case .dazed: 1.9
        }
    }
}

public extension HotPotatoCard {
    var skin: PotatoSkin {
        PotatoSkin(rawValue: theme) ?? .classic
    }
}
