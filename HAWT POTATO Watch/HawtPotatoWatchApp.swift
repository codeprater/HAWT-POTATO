import SwiftUI
import WatchConnectivity
import HAWTPotatoCore

@main
struct HawtPotatoWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
        }
    }
}

@Observable
@MainActor
final class WatchModel: NSObject, WCSessionDelegate {
    var snapshot: WatchSnapshot?
    var now = Date.now

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = .now }
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data,
              let snap = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        Task { @MainActor in self.snapshot = snap }
    }
}

struct WatchRootView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        Group {
            if let card = model.snapshot?.holding.first {
                holding(card)
            } else if let card = model.snapshot?.watching.first {
                watching(card)
            } else if let card = model.snapshot?.history.first {
                exploded(card)
            } else {
                VStack {
                    Text("🥔").font(.largeTitle)
                    Text("HAWT POTATO")
                        .font(.headline)
                    Text("Time To Cook!!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(HPColor.nearBlack, for: .navigation)
    }

    private func holding(_ card: HotPotatoCard) -> some View {
        let left = card.clockText(at: model.now, isHolder: true)
        return VStack(spacing: 6) {
            PotatoArt(skin: card.skin, size: 52)
            if card.gameMode != .classic {
                Text(card.gameMode.title)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(card.gameMode == .suddenDeath ? HPColor.criticalRed : HPColor.flameYellow)
            }
            Text(left)
                .font(card.hidesClock ? .system(.headline).bold() : .system(.title, design: .monospaced).bold())
                .foregroundStyle(card.heat(at: model.now) >= .critical ? HPColor.criticalRed : HPColor.flameYellow)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Text(ProductCanon.voice.youHaveIt)
                .font(.caption.weight(.bold))
            Text(ProductCanon.voice.throwIt)
                .font(.caption.weight(.heavy))
                .foregroundStyle(HPColor.potatoOrange)
        }
        .accessibilityLabel("You have it. \(left). Throw.")
    }

    private func watching(_ card: HotPotatoCard) -> some View {
        VStack(spacing: 6) {
            PotatoArt(skin: card.skin, size: 40)
            Text(ProductCanon.voice.currentlyWith)
                .font(.caption2)
            Text(card.currentHolder.displayName.uppercased())
                .font(.headline)
            Text(card.clockText(at: model.now, isHolder: false))
                .font(card.hidesClock ? .system(.caption).bold() : .system(.title3, design: .monospaced).bold())
                .foregroundStyle(HPColor.flameYellow)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
    }

    private func exploded(_ card: HotPotatoCard) -> some View {
        VStack {
            Text("💥")
            Text("\((card.explosion?.loser.displayName ?? card.currentHolder.displayName).uppercased())")
                .font(.headline)
            Text(ProductCanon.voice.theyGotCooked)
                .font(.caption)
        }
    }
}
