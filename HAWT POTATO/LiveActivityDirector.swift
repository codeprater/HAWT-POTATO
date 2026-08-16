import Foundation
import ActivityKit
import HAWTPotatoCore

@MainActor
final class LiveActivityDirector {
    static let shared = LiveActivityDirector()
    private var lastFingerprint = ""
    private var lastSync = Date.distantPast

    func sync(store: PotatoStore) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let card = store.hottestHeld else {
            lastFingerprint = ""
            endAll()
            return
        }
        let state = PotatoLiveAttributes.state(for: card, me: store.me, now: store.now)
        let fingerprint = "\(card.id.uuidString)|\(state.clockText)|\(state.heat)|\(state.exploded)"
        if fingerprint == lastFingerprint { return }
        if Date.now.timeIntervalSince(lastSync) < 1.2, Activity<PotatoLiveAttributes>.activities.contains(where: { $0.attributes.potatoID == card.id.uuidString }) {
            return
        }
        lastFingerprint = fingerprint
        lastSync = .now

        let existing = Activity<PotatoLiveAttributes>.activities.first { $0.attributes.potatoID == card.id.uuidString }
        if let existing {
            Task { await existing.update(.init(state: state, staleDate: card.lethalDeadline())) }
            endOthers(except: card.id.uuidString)
            return
        }
        endAll()
        let attributes = PotatoLiveAttributes(potatoID: card.id.uuidString, shortCode: card.shortCode)
        _ = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: card.lethalDeadline()),
            pushType: nil
        )
    }

    func endAll() {
        for activity in Activity<PotatoLiveAttributes>.activities {
            Task {
                await activity.end(
                    .init(state: activity.content.state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
    }

    private func endOthers(except id: String) {
        for activity in Activity<PotatoLiveAttributes>.activities where activity.attributes.potatoID != id {
            Task {
                await activity.end(
                    .init(state: activity.content.state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
    }
}
