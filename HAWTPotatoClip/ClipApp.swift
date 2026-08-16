import SwiftUI
import StoreKit
import HAWTPotatoCore

@main
struct HawtPotatoClipApp: App {
    var body: some Scene {
        WindowGroup {
            ClipRoot()
        }
    }
}

struct ClipRoot: View {
    @State private var store = PotatoStore()
    @State private var card: HotPotatoCard?
    @State private var now = Date.now

    var body: some View {
        ZStack {
            HPColor.nearBlack.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("HAWT POTATO")
                    .font(HPFont.title(28))
                    .foregroundStyle(.white)
                if let card {
                    Text("🔥🥔").font(.system(size: 72))
                    Text(card.clockText(at: now, isHolder: true))
                        .font(card.hidesClock ? HPFont.title(22) : HPFont.timer(44))
                        .foregroundStyle(HPColor.flameYellow)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                    Text("\(card.creator.displayName.uppercased()) THREW YOU A POTATO")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Button(ProductCanon.voice.installToCatchIt) {
                        presentAppStoreOverlay()
                    }
                    .font(HPFont.action())
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(HPColor.potatoOrange, in: Capsule())
                    .foregroundStyle(.black)
                } else {
                    Text("🥔")
                    Text("Install to catch it.")
                        .foregroundStyle(.white)
                    Button("Get HAWT POTATO") {
                        presentAppStoreOverlay()
                    }
                    .foregroundStyle(HPColor.potatoOrange)
                }
            }
            .padding(24)
        }
        .onOpenURL { url in
            Task { await load(url) }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                Task { await load(url) }
            }
        }
        .onAppear {
            presentAppStoreOverlay()
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                Task { @MainActor in now = .now }
            }
        }
    }

    private func presentAppStoreOverlay() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let overlay = SKOverlay(configuration: SKOverlay.AppClipConfiguration(position: .bottom))
        overlay.present(in: scene)
    }

    private func load(_ url: URL) async {
        guard let id = PotatoLink.id(from: url) else { return }
#if canImport(CloudKit)
        if let remote = try? await CloudKitPotatoService().fetch(id: id) {
            card = remote
            store.ingest(remote, asReceive: true)
        }
#endif
    }
}
