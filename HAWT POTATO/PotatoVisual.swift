import SwiftUI
import HAWTPotatoCore

struct PotatoVisual: View {
    var heat: PotatoHeat
    var exploded: Bool
    var reduceMotion: Bool
    var size: CGFloat = 132
    var skin: PotatoSkin = .classic
    var live: Bool = true

    var body: some View {
        let motionOn = live && !reduceMotion && !exploded
        ZStack {
            Circle()
                .fill(exploded ? HPColor.criticalRed.opacity(0.35) : HPColor.potatoOrange.opacity(glow))
                .frame(width: size * 1.15, height: size * 1.15)
                .blur(radius: motionOn ? 18 : 8)
                .scaleEffect(motionOn ? pulse : 1)
            PotatoArt(skin: skin, exploded: exploded, size: size, live: motionOn, heat: heat)
                .scaleEffect(motionOn ? bounce : 1)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        }
        .frame(width: size * 1.4, height: size * 1.4)
        .animation(motionOn ? .easeInOut(duration: duration).repeatForever(autoreverses: true) : nil, value: heat)
    }

    private var glow: Double {
        switch heat {
        case .normal: 0.28
        case .warming: 0.45
        case .hot: 0.65
        case .critical: 0.8
        case .finalCountdown: 1
        }
    }

    private var bounce: CGFloat {
        switch heat {
        case .normal: 1.03
        case .warming: 1.06
        case .hot: 1.1
        case .critical: 1.14
        case .finalCountdown: 1.18
        }
    }

    private var pulse: CGFloat {
        heat == .finalCountdown ? 1.12 : 1.04
    }

    private var duration: Double {
        switch heat {
        case .normal: 1.4
        case .warming: 1.0
        case .hot: 0.7
        case .critical: 0.35
        case .finalCountdown: 0.18
        }
    }
}

struct HeatBadge: View {
    var heat: PotatoHeat

    var body: some View {
        Text(heat.accessibilityLabel.uppercased())
            .font(.caption.weight(.heavy))
            .tracking(1.2)
            .foregroundStyle(heat == .critical || heat == .finalCountdown ? HPColor.criticalRed : HPColor.flameYellow)
            .accessibilityLabel(heat.accessibilityLabel)
    }
}

struct ThrowButton: View {
    var title: String = ProductCanon.voice.throwIt
    var color: Color = HPColor.potatoOrange
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HPFont.action())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .foregroundStyle(.black)
                .background(color, in: Capsule())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityAddTraits(.isButton)
    }
}

struct ScreenBackground: View {
    var heat: PotatoHeat = .normal
    var exploded: Bool = false
    var branded: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .light {
                LinearGradient(
                    colors: [HPColor.cream, HPColor.tan, HPColor.lightBrown.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        accent.opacity(branded ? 0.22 : opacity * 0.38),
                        .clear
                    ],
                    center: .top,
                    startRadius: 16,
                    endRadius: branded ? 520 : 420
                )
            } else {
                HPColor.nearBlack
                LinearGradient(
                    colors: [
                        accent.opacity(branded ? 0.62 : opacity),
                        HPColor.flameYellow.opacity(branded ? 0.22 : 0.08),
                        HPColor.nearBlack
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        accent.opacity(branded ? 0.5 : opacity),
                        .clear
                    ],
                    center: .top,
                    startRadius: 20,
                    endRadius: branded ? 520 : 420
                )
            }
        }
        .ignoresSafeArea()
    }

    private var accent: Color {
        exploded || heat == .finalCountdown || heat == .critical ? HPColor.criticalRed : HPColor.potatoOrange
    }

    private var opacity: Double {
        switch heat {
        case .normal: 0.28
        case .warming: 0.36
        case .hot: 0.46
        case .critical: 0.58
        case .finalCountdown: 0.7
        }
    }
}

struct PotatoListRow: View {
    let card: HotPotatoCard
    var exploded: Bool
    var now: Date

    var body: some View {
        HStack(spacing: 12) {
            PotatoArt(skin: card.skin, exploded: exploded, size: 72, live: false)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(card.shortCode)")
                    .font(.headline)
                    .foregroundStyle(HPColor.ink)
                Text(exploded
                     ? "Exploded on \(card.explosion?.loser.displayName ?? card.currentHolder.displayName)"
                     : card.isPaused
                        ? "PAUSED by \(card.pausedBy?.displayName ?? "someone") · with \(card.currentHolder.displayName)"
                        : "\(card.gameMode == .classic ? "Currently with" : card.gameMode.title) \(card.currentHolder.displayName)")
                    .font(.caption)
                    .foregroundStyle(HPColor.muted)
            }
            Spacer()
            Text(exploded ? "\(card.passCount) passes" : card.clockText(at: now, isHolder: false))
                .font(exploded ? .caption : (card.hidesClock ? .caption.weight(.heavy) : HPFont.timer(16)))
                .foregroundStyle(exploded ? HPColor.faint : (card.isPaused ? HPColor.potatoOrange : HPColor.flameYellow))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right")
                .foregroundStyle(HPColor.faint)
        }
        .padding(10)
        .background(HPColor.card, in: RoundedRectangle(cornerRadius: 16))
    }
}
