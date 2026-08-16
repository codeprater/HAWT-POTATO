import Foundation
import UserNotifications
import UniformTypeIdentifiers
import HAWTPotatoCore

enum NotificationLaunch: Equatable {
    case showIncoming(UUID)
    case throwPotato(UUID)
}

@MainActor
final class NotificationDirector: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDirector()
    var onLaunch: ((NotificationLaunch) -> Void)?

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        let throwAction = UNNotificationAction(identifier: "THROW", title: "THROW", options: [.foreground])
        let openAction = UNNotificationAction(identifier: "OPEN", title: "PASS IT", options: [.foreground])
        let category = UNNotificationCategory(
            identifier: "HAWT_POTATO",
            actions: [throwAction, openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestIfNeeded() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func potatoReceived(_ card: HotPotatoCard, from name: String, settings: AppSettings, badge: Int) {
        guard settings.notifyReceived else { return }
        let delay = PotatoBrain.notificationDelay(for: card.skin)
        let title = PotatoBrain.notificationTitle(card: card)
        let line = "\(name) threw you \(card.callsign)."
        Task {
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            notify(
                title: title,
                body: line,
                id: "recv-\(card.id)-\(card.passGeneration)",
                soundName: "PotatoCatch.wav",
                badge: badge,
                cardID: card.id
            )
        }
    }

    func syncAppIconBadge(_ count: Int) {
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    func warning(_ card: HotPotatoCard, settings: AppSettings) {
        guard settings.notifyWarnings else { return }
        let copy = PotatoBrain.warningCopy(card: card)
        if card.gameMode == .suddenDeath, let window = card.throwWindowRemaining(), window <= 8 {
            notify(title: copy.title, body: copy.body, id: "sd-\(card.id)-\(card.passGeneration)", cardID: card.id)
            return
        }
        if card.hidesClock {
            if card.heat() >= .hot {
                notify(title: copy.title, body: copy.body, id: "warn-\(card.id)-\(card.heat().rawValue)", cardID: card.id)
            }
            return
        }
        let left = card.remaining()
        if left <= 10 {
            notify(title: copy.title, body: copy.body, id: "crit-\(card.id)", cardID: card.id)
        } else if left <= 30 {
            notify(title: copy.title, body: copy.body, id: "warn-\(card.id)", cardID: card.id)
        }
    }

    func exploded(_ card: HotPotatoCard, settings: AppSettings) {
        guard settings.notifyExplosion || settings.notifyResults else { return }
        let cooked = card.explosion?.loser.displayName ?? card.currentHolder.displayName
        notify(
            title: "💥 \(ProductCanon.voice.theyAreCooked)",
            body: "\(cooked) · \(PotatoBrain.explodeRecap(card: card))",
            id: "boom-\(card.id)",
            cardID: card.id
        )
    }

    func pauseChanged(_ card: HotPotatoCard, settings: AppSettings) {
        guard settings.notifyMovement || settings.notifyWarnings else { return }
        if card.isPaused {
            let who = card.pausedBy?.displayName ?? "Someone"
            notify(
                title: "⏸ \(card.callsign) is paused",
                body: "\(who) paused it. The fuse is frozen. Everyone in this potato can see this.",
                id: "pause-\(card.id)-\(card.passGeneration)",
                cardID: card.id
            )
        } else {
            notify(
                title: "▶️ \(card.callsign) is live again",
                body: "The fuse is running. Currently with \(card.currentHolder.displayName).",
                id: "resume-\(card.id)-\(card.passGeneration)",
                cardID: card.id
            )
        }
    }

    func moved(_ card: HotPotatoCard, settings: AppSettings) {
        guard settings.notifyMovement else { return }
        notify(
            title: "🥔 Your potato moved again.",
            body: "Currently with \(card.currentHolder.displayName)",
            id: "move-\(card.id)-\(card.passGeneration)",
            cardID: card.id
        )
    }

    private func notify(title: String, body: String, id: String, soundName: String? = nil, badge: Int? = nil, cardID: UUID? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let soundName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        } else {
            content.sound = .default
        }
        if let badge {
            content.badge = NSNumber(value: badge)
        }
        if let cardID {
            content.userInfo = ["potatoID": cardID.uuidString]
        }
        content.categoryIdentifier = "HAWT_POTATO"
        content.threadIdentifier = "hawt-potato"
        if let icon = iconAttachment() {
            content.attachments = [icon]
        }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func iconAttachment() -> UNNotificationAttachment? {
        guard let source = Bundle.main.url(forResource: "NotificationIcon", withExtension: "png") else {
            return nil
        }
        let copy = FileManager.default.temporaryDirectory
            .appending(path: "hawt-banner-\(UUID().uuidString).png")
        do {
            try FileManager.default.copyItem(at: source, to: copy)
            return try UNNotificationAttachment(
                identifier: "hawt-icon",
                url: copy,
                options: [UNNotificationAttachmentOptionsTypeHintKey: UTType.png.identifier]
            )
        } catch {
            return nil
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.identifier.hasPrefix("recv-") {
            [.banner, .badge, .list]
        } else {
            [.banner, .sound, .badge, .list]
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let raw = info["potatoID"] as? String, let id = UUID(uuidString: raw) else { return }
        let action = response.actionIdentifier
        await MainActor.run {
            if action == "THROW" {
                onLaunch?(.throwPotato(id))
            } else {
                onLaunch?(.showIncoming(id))
            }
        }
    }
}
