import UIKit
import Messages
import SwiftUI
import HAWTPotatoCore

@objc(MessagesViewController)
final class MessagesViewController: MSMessagesAppViewController {
    private let store = PotatoStore()
    private let bridge = MessageBridge()
    private var hosting: UIHostingController<AnyView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        let root = MessageRoot(
            bridge: bridge,
            onSend: { [weak self] card in self?.send(card) },
            onCatch: { [weak self] card in self?.catchPotato(card) },
            onLight: { [weak self] seconds in self?.lightAndThrow(seconds) },
            onExpand: { [weak self] in self?.requestPresentationStyle(.expanded) }
        )
        .environment(store)
        let hosting = UIHostingController(rootView: AnyView(root))
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
        self.hosting = hosting
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        sync(conversation)
        Task { await pullSelected(conversation) }
    }

    override func didBecomeActive(with conversation: MSConversation) {
        super.didBecomeActive(with: conversation)
        sync(conversation)
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        sync(conversation)
        Task { await pullSelected(conversation) }
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        sync(conversation)
        Task { await pullSelected(conversation) }
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        bridge.compact = presentationStyle == .compact
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        bridge.compact = presentationStyle == .compact
        if let conversation = activeConversation {
            sync(conversation)
        }
    }

    private func sync(_ conversation: MSConversation) {
        bridge.compact = presentationStyle == .compact
        bridge.isGroup = conversation.remoteParticipantIdentifiers.count > 1
        bridge.selectedID = conversation.selectedMessage?.url.flatMap(PotatoLink.id(from:))
        bridge.status = ""
    }

    private func pullSelected(_ conversation: MSConversation) async {
        if let id = conversation.selectedMessage?.url.flatMap(PotatoLink.id(from:)) {
            _ = await store.pullRemote(id)
            await MainActor.run {
                bridge.selectedID = id
            }
        }
        await store.refreshHeldFromCloud()
    }

    private func lightAndThrow(_ seconds: TimeInterval) {
        guard store.hasCompletedOnboarding else {
            bridge.status = "Open HAWT POTATO and pick a name first."
            return
        }
        let card = store.lightPotato(
            duration: seconds,
            locationSharing: .hidden,
            location: nil,
            gameMode: .classic,
            theme: PotatoSkin.classic.rawValue
        )
        send(card)
    }

    private func catchPotato(_ card: HotPotatoCard) {
        Task {
            _ = await store.pullRemote(card.id)
            do {
                try store.claimPotato(card.id, location: nil)
                await MainActor.run {
                    if let live = store.potato(card.id) {
                        insert(live, caption: "\(store.me.displayName) caught it")
                    }
                    bridge.status = "YOU HAVE IT"
                }
            } catch {
                await MainActor.run {
                    bridge.status = "Someone else caught it first."
                }
            }
        }
    }

    private func send(_ card: HotPotatoCard) {
        do {
            if card.isHeld(by: store.me), card.status != .inFlight {
                try store.offerPotatoToGroup(card.id)
            }
        } catch {
            bridge.status = error.localizedDescription
            return
        }
        let live = store.potato(card.id) ?? card
        insert(live, caption: "\(store.me.displayName) threw a potato")
        requestPresentationStyle(.compact)
    }

    private func insert(_ card: HotPotatoCard, caption: String) {
        guard let conversation = activeConversation else { return }
        let session = conversation.selectedMessage?.session ?? MSSession()
        let message = MSMessage(session: session)
        let layout = MSMessageTemplateLayout()
        layout.image = PotatoShareArtwork.image(for: card, senderName: store.me.displayName)
        layout.caption = "🔥 HAWT POTATO"
        let groupNote = bridge.isGroup ? "Group chat · first catch wins" : "Tap CATCH to hold it"
        layout.subcaption = "\(caption) · \(card.clockText(isHolder: true))"
        layout.trailingCaption = ProductCanon.voice.passIt
        layout.trailingSubcaption = groupNote
        message.layout = layout
        message.url = card.webLink
        message.summaryText = "HAWT POTATO — \(caption)"
        conversation.insert(message) { [weak self] error in
            if let error {
                self?.bridge.status = error.localizedDescription
            }
        }
    }
}

@Observable
final class MessageBridge {
    var compact = true
    var isGroup = false
    var selectedID: UUID?
    var status = ""
}

struct MessageRoot: View {
    @Environment(PotatoStore.self) private var store
    @Bindable var bridge: MessageBridge
    var onSend: (HotPotatoCard) -> Void
    var onCatch: (HotPotatoCard) -> Void
    var onLight: (TimeInterval) -> Void
    var onExpand: () -> Void

    var body: some View {
        ZStack {
            HPColor.nearBlack
            if bridge.compact {
                compactStrip
            } else {
                expandedBoard
            }
        }
    }

    private var incoming: HotPotatoCard? {
        if let id = bridge.selectedID, let card = store.potato(id), card.status == .inFlight, !card.isHeld(by: store.me) {
            return card
        }
        return store.potatoes.first { $0.status == .inFlight && !$0.isHeld(by: store.me) }
    }

    private var compactStrip: some View {
        HStack(spacing: 10) {
            if let incoming {
                compactChip(title: "CATCH", subtitle: incoming.callsign) {
                    onCatch(incoming)
                }
                .contextMenu {
                    Button("Catch this potato", systemImage: "hand.raised.fill") {
                        onCatch(incoming)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.holding) { card in
                        compactChip(title: "THROW", subtitle: card.clockText(at: store.now, isHolder: true)) {
                            onSend(card)
                        }
                        .contextMenu {
                            Button("Throw into this chat", systemImage: "bubble.left.and.bubble.right.fill") {
                                onSend(card)
                            }
                            Button("Open potato", systemImage: "arrow.up.left.and.arrow.down.right") {
                                onExpand()
                            }
                        }
                    }
                    compactChip(title: "NEW", subtitle: "60s") {
                        onExpand()
                    }
                    .contextMenu {
                        Button("Light 30s and throw") { onLight(30) }
                        Button("Light 1 min and throw") { onLight(60) }
                        Button("Light 2 min and throw") { onLight(120) }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 8)
    }

    private func compactChip(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(HPColor.potatoOrange, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var expandedBoard: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(bridge.isGroup ? "GROUP CHAT" : "IMESSAGE")
                    .font(.caption.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(HPColor.flameYellow)
                Text(bridge.isGroup ? "First to tap CATCH holds it." : "Throw it. They tap CATCH.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                if let incoming {
                    PotatoArt(skin: incoming.skin, exploded: false, size: 120)
                    Text(incoming.callsign.uppercased())
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(HPColor.potatoOrange)
                    Text(incoming.clockText(at: store.now, isHolder: false))
                        .font(HPFont.timer(36))
                        .foregroundStyle(HPColor.flameYellow)
                    Button("CATCH") { onCatch(incoming) }
                        .font(HPFont.action())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(HPColor.potatoOrange, in: Capsule())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                } else if let card = store.hottestHeld {
                    PotatoArt(skin: card.skin, exploded: false, size: 120)
                    Text(card.clockText(at: store.now, isHolder: true))
                        .font(card.hidesClock ? HPFont.title(20) : HPFont.timer(36))
                        .foregroundStyle(HPColor.flameYellow)
                    Text(ProductCanon.voice.youHaveIt)
                        .foregroundStyle(.white)
                    Button("THROW INTO THIS CHAT") { onSend(card) }
                        .font(HPFont.action())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(HPColor.potatoOrange, in: Capsule())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .contextMenu {
                            Button("Throw into this chat", systemImage: "bubble.left.and.bubble.right.fill") {
                                onSend(card)
                            }
                        }
                    Text("Long-press a potato on Home to send even faster.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    Text("HAWT POTATO")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(store.hasCompletedOnboarding ? "Light one and throw it into this chat." : "Open HAWT POTATO and pick a name first.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                if store.hasCompletedOnboarding {
                    HStack(spacing: 8) {
                        lightButton("30s", 30)
                        lightButton("1 min", 60)
                        lightButton("2 min", 120)
                    }
                    .padding(.top, 4)
                }

                if !bridge.status.isEmpty {
                    Text(bridge.status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HPColor.flameYellow)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
        }
    }

    private func lightButton(_ title: String, _ seconds: TimeInterval) -> some View {
        Button(title) { onLight(seconds) }
            .font(.caption.weight(.heavy))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.12), in: Capsule())
            .foregroundStyle(.white)
            .contextMenu {
                Button("Light \(title) and throw into this chat") { onLight(seconds) }
            }
    }
}
