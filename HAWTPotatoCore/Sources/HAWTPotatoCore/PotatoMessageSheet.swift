import SwiftUI

public struct PotatoMessageSheet: View {
    public var card: HotPotatoCard
    public var senderName: String
    public var now: Date

    public init(card: HotPotatoCard, senderName: String, now: Date = .now) {
        self.card = card
        self.senderName = senderName
        self.now = now
    }

    private var heat: PotatoHeat { card.heat(at: now) }
    private var exploded: Bool { card.status == .exploded }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(HPColor.nearBlack)
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            HPColor.potatoOrange.opacity(0.55),
                            HPColor.nearBlack.opacity(0.2),
                            HPColor.nearBlack
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RadialGradient(
                colors: [
                    (exploded || heat == .finalCountdown || heat == .critical ? HPColor.criticalRed : HPColor.flameYellow)
                        .opacity(0.55),
                    HPColor.potatoOrange.opacity(0.2),
                    .clear
                ],
                center: .top,
                startRadius: 10,
                endRadius: 280
            )
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))

            VStack(spacing: 14) {
                Text(card.callsign.uppercased())
                    .font(.system(size: 18, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.92))

                ZStack {
                    Circle()
                        .fill(HPColor.potatoOrange.opacity(0.35))
                        .frame(width: 150, height: 150)
                        .blur(radius: 18)
                    PotatoArt(skin: card.skin, exploded: exploded, size: 132)
                }
                .padding(.top, 4)

                if !exploded {
                    Text(heat.accessibilityLabel.uppercased())
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(heat == .critical || heat == .finalCountdown ? HPColor.criticalRed : HPColor.flameYellow)

                    if card.gameMode != .classic {
                        Text(card.gameMode == .suddenDeath ? ProductCanon.voice.throwOrDie : card.gameMode.title)
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(card.gameMode == .suddenDeath ? HPColor.criticalRed : HPColor.flameYellow)
                    }

                    Text(card.clockText(at: now, isHolder: true))
                        .font(card.hidesClock ? .system(size: 28, weight: .black) : .system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundStyle(heat == .critical || heat == .finalCountdown ? HPColor.criticalRed : HPColor.flameYellow)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .monospacedDigit()
                } else {
                    Text("\(card.explosion?.loser.displayName.uppercased() ?? "SOMEONE") GOT COOKED")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 4) {
                    Text("\(senderName.uppercased()) SENT YOU")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    Text("A POTATO")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

                if !exploded {
                    Text(ProductCanon.voice.passIt)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .background(HPColor.potatoOrange, in: Capsule())
                }

                Spacer(minLength: 0)

                Text("#\(card.shortCode)  ·  \(card.passCount) passes")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 22)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [HPColor.flameYellow.opacity(0.9), HPColor.potatoOrange, HPColor.criticalRed.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        )
        .frame(width: 360, height: 480)
    }
}

public struct PotatoDamageSheet: View {
    public var card: HotPotatoCard
    public var viewerName: String

    public init(card: HotPotatoCard, viewerName: String) {
        self.card = card
        self.viewerName = viewerName
    }

    private var loser: String {
        card.explosion?.loser.displayName ?? card.currentHolder.displayName
    }

    private var cookedMe: Bool {
        let loserName = card.explosion?.loser.displayName ?? card.currentHolder.displayName
        return loserName.caseInsensitiveCompare(viewerName) == .orderedSame
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 18 / 255, green: 8 / 255, blue: 6 / 255),
                            HPColor.nearBlack,
                            Color(red: 8 / 255, green: 6 / 255, blue: 4 / 255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RadialGradient(
                colors: [HPColor.potatoOrange.opacity(0.42), HPColor.criticalRed.opacity(0.12), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 320
            )
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))

            VStack(spacing: 0) {
                Text("HAWT POTATO")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3.2)
                    .foregroundStyle(.white.opacity(0.42))
                    .padding(.top, 26)

                ZStack {
                    Circle()
                        .fill(HPColor.criticalRed.opacity(0.28))
                        .frame(width: 168, height: 168)
                        .blur(radius: 26)
                    PotatoArt(skin: card.skin, exploded: true, size: 148)
                }
                .padding(.top, 18)
                .padding(.bottom, 10)

                Text(cookedMe ? "You got cooked." : "They are cooked.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(loser)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HPColor.flameYellow)
                    .padding(.top, 6)

                if let note = card.note, !note.isEmpty {
                    Text("“\(note)”")
                        .font(.system(size: 20, weight: .medium, design: .serif).italic())
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 16)
                }

                HStack(spacing: 8) {
                    damageStat(card.passCount == 1 ? "1 pass" : "\(card.passCount) passes")
                    damageStat(card.gameMode == .mystery ? "Mystery" : card.duration.hpClock)
                    if card.gameMode != .classic {
                        damageStat(card.gameMode.title)
                    }
                }
                .padding(.top, 22)

                if !storyline.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(storyline.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                }

                Spacer(minLength: 12)

                Text(card.callsign.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.38))
                    .padding(.bottom, 22)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .frame(width: 360, height: 520)
    }

    private var storyline: [String] {
        card.history
            .filter { $0.action == .created || $0.action == .received || $0.action == .exploded }
            .suffix(4)
            .map { event in
                switch event.action {
                case .created: "Lit by \(event.player.displayName)"
                case .received: "Caught by \(event.player.displayName)"
                case .exploded: "Cooked \(event.player.displayName)"
                default: event.player.displayName
                }
            }
    }

    private func damageStat(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.86))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.08), in: Capsule())
    }
}

#if os(iOS)
import UIKit

public enum PotatoShareArtwork {
    @MainActor
    public static func image(for card: HotPotatoCard, senderName: String, now: Date = .now) -> UIImage {
        let renderer = ImageRenderer(
            content: PotatoMessageSheet(card: card, senderName: senderName, now: now)
        )
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 480)
        return renderer.uiImage ?? UIImage()
    }

    @MainActor
    public static func damageImage(for card: HotPotatoCard, viewerName: String) -> UIImage {
        let renderer = ImageRenderer(
            content: PotatoDamageSheet(card: card, viewerName: viewerName)
        )
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 520)
        return renderer.uiImage ?? UIImage()
    }

    @MainActor
    public static func pngURL(for card: HotPotatoCard, senderName: String, now: Date = .now) throws -> URL {
        let image = image(for: card, senderName: senderName, now: now)
        guard let data = image.pngData() else {
            throw PotatoError.unknownPotato
        }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "HAWT-POTATO-\(card.shortCode).png")
        try data.write(to: url, options: [.atomic])
        return url
    }
}
#endif
