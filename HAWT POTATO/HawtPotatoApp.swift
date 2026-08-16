import SwiftUI
import HAWTPotatoCore
import UniformTypeIdentifiers

@main
struct HawtPotatoApp: App {
    @State private var store = PotatoStore()

    var body: some Scene {
        WindowGroup {
            AppHostView()
                .environment(store)
        }
    }
}

private struct AppHostView: View {
    @Environment(PotatoStore.self) private var store
    @State private var showLaunch = true
    @State private var explosionName: String?
    @State private var explosionIsMe = false
    @State private var explosionRecap: String?
    @State private var recapShare: HotPotatoCard?

    var body: some View {
        ZStack {
            AppRootView()
                .opacity(showLaunch ? 0 : 1)
            if showLaunch {
                LaunchView { showLaunch = false }
            }
            AppIncomingCover()
            AppExplosionCover(
                explosionName: $explosionName,
                explosionIsMe: $explosionIsMe,
                explosionRecap: $explosionRecap
            )
        }
        .buttonStyle(.haptic)
        .preferredColorScheme(store.settings.appearance.colorScheme)
        .sheet(item: $recapShare) { card in
            ShareResultView(text: store.shareResultText(card), card: card)
        }
        .background {
            AppRuntimeHooks(
                explosionName: $explosionName,
                explosionIsMe: $explosionIsMe,
                explosionRecap: $explosionRecap,
                recapShare: $recapShare
            )
        }
    }
}

private struct AppIncomingCover: View {
    @Environment(PotatoStore.self) private var store

    var body: some View {
        if let incoming = store.frontIncoming {
            ReceiveCover(
                card: incoming,
                queuedBehind: store.queuedIncomingCount,
                onThrow: { store.beginThrowFromReceive() },
                onBack: { store.clearIncoming() }
            )
            .id("\(incoming.id.uuidString)-\(incoming.passGeneration)")
            .transition(.opacity)
        }
    }
}

private struct AppExplosionCover: View {
    @Binding var explosionName: String?
    @Binding var explosionIsMe: Bool
    @Binding var explosionRecap: String?

    var body: some View {
        if let explosionName {
            ExplosionCover(
                name: explosionName,
                isMe: explosionIsMe,
                recap: explosionRecap,
                onBack: {
                    self.explosionName = nil
                    explosionRecap = nil
                }
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    self.explosionName = nil
                    self.explosionRecap = nil
                }
            }
        }
    }
}

private struct AppRuntimeHooks: View {
    @Environment(PotatoStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Binding var explosionName: String?
    @Binding var explosionIsMe: Bool
    @Binding var explosionRecap: String?
    @Binding var recapShare: HotPotatoCard?
    @State private var lastLivePull = Date.distantPast

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear(perform: bootstrap)
            .onOpenURL(perform: handle)
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL {
                    handle(url)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                handleScenePhase(phase)
            }
            .onChange(of: store.incomingQueue) { old, new in
                notifyIncoming(old: old, new: new)
            }
            .onChange(of: store.history.first?.id) { _, _ in
                presentExplosionIfNeeded()
            }
            .onChange(of: NearbyThrowService.shared.receiveStamp) { _, _ in
                ingestNearby()
            }
            .onChange(of: store.me.id) { _, _ in
                NearbyThrowService.shared.start(as: store.me)
            }
            .onChange(of: store.holding.count) { _, _ in
                WatchBridge.shared.push()
                LiveActivityDirector.shared.sync(store: store)
                NotificationDirector.shared.syncAppIconBadge(store.homeBadgeCount)
            }
            .onChange(of: store.homeBadgeCount) { _, count in
                NotificationDirector.shared.syncAppIconBadge(count)
            }
            .onChange(of: store.settings.haptics) { _, _ in
                SensoryDirector.shared.sync(settings: store.settings)
            }
            .onChange(of: store.settings.soundEffects) { _, _ in
                SensoryDirector.shared.sync(settings: store.settings)
            }
            .onChange(of: store.now) { _, now in
                syncFuseAlert()
                guard store.potatoes.contains(where: { $0.status == .inFlight }) else { return }
                guard now.timeIntervalSince(lastLivePull) >= 4 else { return }
                lastLivePull = now
                Task { await store.refreshLiveFromCloud() }
            }
            .onChange(of: store.pauseEpoch) { _, _ in
                handlePauseNotice()
            }
    }

    private func bootstrap() {
        SensoryDirector.shared.prepare()
        SensoryDirector.shared.sync(settings: store.settings)
        NotificationDirector.shared.configure()
        NotificationDirector.shared.onLaunch = { launch in
            switch launch {
            case .showIncoming(let id):
                store.enqueueIncoming(id)
            case .throwPotato(let id):
                store.beginThrow(id)
            }
        }
        WatchBridge.shared.activate(store: store)
        NearbyThrowService.shared.start(as: store.me)
        Task { await ContactDirectory.shared.refreshIfAuthorized() }
        Task { await store.refreshHeldFromCloud() }
        Task { await NotificationDirector.shared.requestIfNeeded() }
        LiveActivityDirector.shared.sync(store: store)
        NotificationDirector.shared.syncAppIconBadge(store.homeBadgeCount)
        syncFuseAlert()
    }

    private func syncFuseAlert() {
        let live = (store.holding + store.watching).filter { !$0.isPaused }
        let left = live.map { $0.remaining(at: store.now) }.min() ?? .greatestFiniteMagnitude
        SensoryDirector.shared.syncFuse(remaining: left, countdownSound: store.settings.countdownSounds)
    }

    private func handlePauseNotice() {
        guard let notice = store.pauseNotice, let card = store.potato(notice.cardID) else { return }
        NearbyThrowService.shared.broadcast(card)
        LiveActivityDirector.shared.sync(store: store)
        WatchBridge.shared.push()
        NotificationDirector.shared.pauseChanged(card, settings: store.settings)
        syncFuseAlert()
    }

    private func ingestNearby() {
        guard var incoming = NearbyThrowService.shared.lastReceived else { return }
        if incoming.status == .exploded || incoming.isPaused || incoming.history.last?.action == .resumed {
            store.ingest(incoming, asReceive: false, syncCloud: true)
            return
        }
        if incoming.currentHolder.id != store.me.id {
            incoming.currentHolder = store.me
        }
        store.ingest(incoming, asReceive: true, syncCloud: true)
    }

    private func notifyIncoming(old: [UUID], new: [UUID]) {
        let added = new.filter { !old.contains($0) }
        for id in added {
            guard let card = store.potato(id), card.isIncomingCatch(for: store.me) else { continue }
            let sender = card.previousHolder?.displayName ?? card.creator.displayName
            SensoryDirector.shared.potatoCaught(
                sound: store.settings.soundEffects,
                haptics: store.settings.haptics
            )
            NotificationDirector.shared.potatoReceived(
                card,
                from: sender,
                settings: store.settings,
                badge: store.homeBadgeCount
            )
        }
    }

    private func presentExplosionIfNeeded() {
        guard let card = store.history.first else { return }
        explosionName = card.explosion?.loser.displayName ?? card.currentHolder.displayName
        explosionIsMe = card.explosion?.loser.id == store.me.id
        explosionRecap = PotatoBrain.explodeRecap(card: card)
        SensoryDirector.shared.theyAreCooked(cardID: card.id, isMe: explosionIsMe)
        NearbyThrowService.shared.broadcast(card)
        NotificationDirector.shared.exploded(card, settings: store.settings)
        if explosionIsMe || card.creator.id == store.me.id {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                recapShare = card
            }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active {
            NearbyThrowService.shared.start(as: store.me)
            store.tick()
            Task { await store.refreshHeldFromCloud() }
            LiveActivityDirector.shared.sync(store: store)
            if let hottest = store.hottestHeld {
                let panic = hottest.gameMode == .suddenDeath
                    ? (hottest.throwWindowRemaining() ?? hottest.remaining()) <= 8
                    : hottest.remaining() <= 30
                if panic {
                    NotificationDirector.shared.warning(hottest, settings: store.settings)
                }
            }
        }
    }

    private func handle(_ url: URL) {
        if url.isFileURL {
            ingestFile(url)
            return
        }
        if let id = PotatoLink.id(from: url) {
            Task { await fetchAndIngest(id) }
        }
    }

    private func ingestFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let card = try? PotatoPayload.card(from: data) else { return }
        store.ingest(card, asReceive: card.isIncomingCatch(for: store.me) || card.status == .inFlight)
        if card.status == .inFlight {
            try? store.claimPotato(card.id, location: nil)
        }
    }

    private func fetchAndIngest(_ id: UUID) async {
        _ = await store.pullRemote(id)
        if let local = store.potato(id) {
            store.ingest(local, asReceive: local.isHeld(by: store.me) == false && local.status == .inFlight)
            if local.status == .inFlight {
                try? store.claimPotato(id, location: nil)
            }
        }
    }
}

struct AppRootView: View {
    @Environment(PotatoStore.self) private var store

    var body: some View {
        if store.hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}
