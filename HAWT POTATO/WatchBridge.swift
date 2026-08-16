import WatchConnectivity
import Foundation
import HAWTPotatoCore

@MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    private var store: PotatoStore?
    private var lastFingerprint = ""

    func activate(store: PotatoStore) {
        self.store = store
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        push()
    }

    func push() {
        guard let store, WCSession.default.activationState == .activated else { return }
        let fingerprint = store.holding.map { "\($0.id.uuidString)-\($0.passGeneration)-\($0.currentHolder.id)" }.joined()
            + "|" + store.watching.map { "\($0.id.uuidString)-\($0.passGeneration)" }.joined()
        if fingerprint == lastFingerprint { return }
        lastFingerprint = fingerprint
        let snapshot = WatchSnapshot(
            holding: store.holding,
            watching: store.watching,
            history: Array(store.history.prefix(3)),
            me: store.me,
            now: store.now
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext(["snapshot": data])
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in push() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
