import SwiftUI
import HAWTPotatoCore

struct HomeView: View {
    @Environment(PotatoStore.self) private var store
    var onThrow: (HotPotatoCard) -> Void
    @State private var creating = false
    @State private var selected: HotPotatoCard?
    @State private var showProfile = false
    @State private var tucked: Set<UUID> = []
    @State private var quickShare: QuickShareRequest?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(heat: store.hottestHeld?.heat(at: store.now) ?? .normal)
                List {
                    Section {
                        if let notice = store.lastHandoff {
                            HandoffHomeBanner(notice: notice) {
                                store.clearHandoff()
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                        }
                        if store.holding.isEmpty {
                            emptyHold
                                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                        } else {
                            Text(ProductCanon.voice.youreHolding)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.flameYellow)
                                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 0, trailing: 8))
                            if let hint = PotatoBrain.hottestQueueHint(holdingCount: store.holding.count) {
                                Text(hint)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(HPColor.potatoOrange)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 4, trailing: 8))
                            }
                            ForEach(store.holding) { card in
                                holdingCard(card)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if let dumper = store.repeatDumper() {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(dumper.displayName) keeps dumping on you.")
                                    .foregroundStyle(HPColor.ink)
                                HStack {
                                    Button("Block") { store.block(dumper) }
                                        .font(.subheadline.weight(.heavy))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(HPColor.criticalRed, in: Capsule())
                                    Button("Not now") { store.dismissNudge(for: dumper) }
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(HPColor.muted)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                        } header: {
                            Text("SAFETY")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.faint)
                        }
                        .listRowBackground(HPColor.card)
                    }

                    if !store.inFlightCatchable.isEmpty {
                        Section {
                            ForEach(store.inFlightCatchable) { card in
                                Button {
                                    catchInFlight(card)
                                } label: {
                                    HStack {
                                        PotatoArt(skin: card.skin, size: 56)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(card.callsign.uppercased())
                                                .font(.headline)
                                                .foregroundStyle(HPColor.ink)
                                            Text("Group throw · tap CATCH")
                                                .font(.caption)
                                                .foregroundStyle(HPColor.faint)
                                        }
                                        Spacer()
                                        Text("CATCH")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(HPColor.potatoOrange, in: Capsule())
                                    }
                                }
                                .buttonStyle(.hapticPlain)
                            }
                        } header: {
                            Text("IN THE AIR")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.flameYellow)
                        }
                        .listRowBackground(HPColor.card)
                    }

                    if !store.watching.isEmpty {
                        Section {
                            ForEach(store.watching) { card in
                                Button {
                                    selected = card
                                } label: {
                                    potatoRow(card, exploded: false)
                                }
                                .buttonStyle(.hapticPlain)
                            }
                        } header: {
                            Text(ProductCanon.voice.findMyPotato)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.faint)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    Section {
                        RecentContactStrip(players: store.visibleRecentPlayers) { contact in
                            sendFast(contact)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8))
                        Button {
                            creating = true
                        } label: {
                            Label(ProductCanon.voice.startAPotato, systemImage: "plus")
                                .font(HPFont.action())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(.black)
                                .background(HPColor.potatoOrange, in: Capsule())
                        }
                        .buttonStyle(.hapticPlain)
                        .padding(.top, 8)
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 24, trailing: 4))
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        PotatoArt(skin: .classic, size: 28)
                        Text("HAWT POTATO")
                            .font(.headline.weight(.black))
                            .foregroundStyle(HPColor.ink)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Text(store.me.initials)
                            .font(.caption.weight(.bold))
                            .padding(8)
                            .background(HPColor.potatoOrange, in: Circle())
                            .foregroundStyle(.black)
                    }
                    .accessibilityLabel("Profile")
                }
            }
            .toolbarBackground(HPColor.nearBlack, for: .navigationBar)
            .sheet(isPresented: $creating) {
                CreatePotatoSheet { card, contact in
                    ContactDirectory.shared.remember(contact)
                    quickShare = QuickShareRequest(
                        card: card,
                        destination: .messages,
                        recipients: [contact.phone]
                    )
                }
                .buttonStyle(.haptic)
            }
            .sheet(item: $selected) { card in
                PotatoDetailView(cardID: card.id)
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(item: $quickShare) { request in
                SharePotatoView(
                    card: store.potato(request.card.id) ?? request.card,
                    senderName: store.me.displayName,
                    destination: request.destination,
                    recipients: request.recipients
                )
                .ignoresSafeArea()
            }
        }
    }

    private var emptyHold: some View {
        VStack(spacing: 10) {
            PotatoArt(skin: .classic, size: 160)
            if store.lastHandoff != nil {
                Text("Not in your hands")
                    .font(HPFont.name())
                    .foregroundStyle(HPColor.ink)
                Text("You passed it. The clock is still running with them.")
                    .foregroundStyle(HPColor.muted)
                    .multilineTextAlignment(.center)
            } else {
                Text("Time To Cook!!")
                    .font(HPFont.name())
                    .foregroundStyle(HPColor.ink)
                Text("Start a potato and throw it.")
                    .foregroundStyle(HPColor.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func potatoRow(_ card: HotPotatoCard, exploded: Bool) -> some View {
        PotatoListRow(card: card, exploded: exploded, now: store.now)
    }

    @ViewBuilder
    private func holdingCard(_ card: HotPotatoCard) -> some View {
        let compact = tucked.contains(card.id)
        let cardView = PotatoCardView(
            card: card,
            me: store.me,
            now: store.now,
            compact: compact,
            onThrow: { onThrow(card) },
            onOpen: { selected = card },
            onBack: { tucked.insert(card.id) },
            onCancelGame: { store.cancelOwnPotato(card.id) },
            onPause: { try? store.togglePause(card.id) },
            onQuickShare: { share(card, $0) },
            onQuickPass: { player, peer in pass(card, to: player, peer: peer) },
            onQuickMessage: { messageContact(card, $0) }
        )
        .quickSendMenu(
            card: card,
            me: store.me,
            onShare: { share(card, $0) },
            onPass: { player, peer in pass(card, to: player, peer: peer) },
            onMessageContact: { messageContact(card, $0) }
        )
        .accessibilityHint("Long press to throw into iMessage, AirDrop, or a nearby player")

        if compact {
            cardView.onTapGesture { tucked.remove(card.id) }
        } else {
            cardView
        }
    }

    private func share(_ card: HotPotatoCard, _ destination: PotatoShareDestination) {
        try? store.offerPotatoToGroup(card.id)
        quickShare = QuickShareRequest(card: store.potato(card.id) ?? card, destination: destination)
    }

    private func messageContact(_ card: HotPotatoCard, _ contact: PhoneContact) {
        ContactDirectory.shared.remember(contact)
        pass(card, to: contact.player, peer: nil)
        quickShare = QuickShareRequest(
            card: store.potato(card.id) ?? card,
            destination: .messages,
            recipients: [contact.phone]
        )
    }

    private func catchInFlight(_ card: HotPotatoCard) {
        Task {
            _ = await store.pullRemote(card.id)
            try? store.claimPotato(card.id, location: nil)
            if let live = store.potato(card.id), live.isHeld(by: store.me) {
                quickShare = QuickShareRequest(card: live, destination: .messages)
            }
        }
    }

    private func sendFast(_ contact: PhoneContact) {
        ContactDirectory.shared.remember(contact)
        if let held = store.hottestHeld {
            messageContact(held, contact)
            return
        }
        let card = store.lightPotato(
            duration: 60,
            locationSharing: store.settings.locationSharing,
            location: nil,
            gameMode: .classic,
            theme: PotatoSkin.classic.rawValue
        )
        try? store.throwPotato(
            card.id,
            to: contact.player,
            location: nil
        )
        quickShare = QuickShareRequest(
            card: store.potato(card.id) ?? card,
            destination: .messages,
            recipients: [contact.phone]
        )
    }

    private func pass(_ card: HotPotatoCard, to player: PlayerRef, peer: NearbyPeer?) {
        do {
            try store.throwPotato(
                card.id,
                to: player,
                location: store.settings.locationSharing == .hidden ? nil : card.lastLocation
            )
            if let peer {
                NearbyThrowService.shared.throwTo(peer, card: store.potato(card.id) ?? card)
            }
        } catch {
            return
        }
    }
}

private struct HandoffHomeBanner: View {
    let notice: HandoffNotice
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ProductCanon.voice.safe)
                .font(.caption.weight(.heavy))
                .foregroundStyle(HPColor.flameYellow)
            Text("You don't have this potato anymore.")
                .font(.headline.weight(.heavy))
                .foregroundStyle(HPColor.ink)
            Text("\(ProductCanon.voice.currentlyWith) \(notice.recipientName.uppercased())")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HPColor.muted)
            Text(notice.callsign.uppercased())
                .font(.caption.weight(.heavy))
                .foregroundStyle(HPColor.potatoOrange)
            Button("OK", action: onDismiss)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(HPColor.potatoOrange, in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HPColor.card, in: RoundedRectangle(cornerRadius: 16))
    }
}
