import SwiftUI
import HAWTPotatoCore

struct LobbyView: View {
    @Environment(PotatoStore.self) private var store
    @Bindable private var nearby = NearbyThrowService.shared
    var onThrow: (HotPotatoCard) -> Void
    var onOpenHome: () -> Void

    @State private var shareDestination: PotatoShareDestination?
    @State private var shareCard: HotPotatoCard?
    @State private var messageRecipients: [String] = []
    @State private var error: String?
    @State private var selectedWatching: HotPotatoCard?
    @State private var showHandoff = false
    @State private var contactQuery = ""
    @Bindable private var contacts = ContactDirectory.shared

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(heat: store.hottestHeld?.heat(at: store.now) ?? .normal)
                List {
                    if !store.holding.isEmpty {
                        Section {
                            Button(action: onOpenHome) {
                                HStack {
                                    Text("YOU'RE HOLDING")
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(HPColor.flameYellow)
                                    Spacer()
                                    Text("\(store.holding.count)")
                                        .font(HPFont.timer(18))
                                        .foregroundStyle(HPColor.potatoOrange)
                                }
                            }
                            if let card = store.hottestHeld {
                                Button {
                                    onThrow(card)
                                } label: {
                                    Text("THROW \(card.callsign.uppercased())")
                                        .font(.subheadline.weight(.heavy))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .foregroundStyle(.black)
                                        .background(HPColor.potatoOrange, in: Capsule())
                                }
                                .quickSendMenu(
                                    card: card,
                                    me: store.me,
                                    onShare: { dest in
                                        try? store.offerPotatoToGroup(card.id)
                                        shareCard = store.potato(card.id) ?? card
                                        messageRecipients = []
                                        shareDestination = dest
                                    },
                                    onPass: { player, peer in
                                        passPlayedBefore(player)
                                        if let peer {
                                            nearby.throwTo(peer, card: store.potato(card.id) ?? card)
                                        }
                                    },
                                    onMessageContact: passContact
                                )
                            }
                            let picks = store.dumpPicks(nearby: nearby.peers.filter { !store.isBlocked($0.player) }.map(\.player))
                            ForEach(picks.prefix(3)) { pick in
                                Button {
                                    passPlayedBefore(pick.player)
                                    if let peer = nearby.peers.first(where: { $0.playerID == pick.player.id }) {
                                        nearby.throwTo(peer, card: store.hottestHeld ?? store.holding[0])
                                    }
                                } label: {
                                    HStack {
                                        Text(pick.player.displayName)
                                            .foregroundStyle(HPColor.ink)
                                        Spacer()
                                        Text(pick.reason.uppercased())
                                            .font(.caption2.weight(.heavy))
                                            .foregroundStyle(HPColor.flameYellow)
                                    }
                                }
                                .buttonStyle(.hapticPlain)
                                .playerSafety(pick.player)
                            }
                        }
                        .listRowBackground(HPColor.card)
                    }

                    Section {
                        if nearby.peers.isEmpty {
                            Text("Nobody in range. Keep HAWT POTATO open on both phones, or throw with Messages or AirDrop.")
                                .font(.subheadline)
                                .foregroundStyle(HPColor.faint)
                        } else {
                            ForEach(nearby.peers.filter { !store.isBlocked($0.player) }) { peer in
                                Button {
                                    passNearby(peer)
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(nearby.isConnected(peer) ? Color.green : Color.yellow)
                                            .frame(width: 8, height: 8)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(peer.displayName)
                                                .font(.headline)
                                                .foregroundStyle(HPColor.ink)
                                            Text(nearby.isConnected(peer) ? "Ready · tap PASS" : "Connecting · keep both apps open")
                                                .font(.caption)
                                                .foregroundStyle(HPColor.faint)
                                        }
                                        Spacer()
                                        Text("PASS")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(HPColor.potatoOrange, in: Capsule())
                                    }
                                }
                                .buttonStyle(.hapticPlain)
                                .playerSafety(peer.player)
                            }
                        }
                    } header: {
                        Text("NEARBY NOW")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.faint)
                    }
                    .listRowBackground(Color.clear)

                    Section {
                        ContactPickList(query: $contactQuery, onPick: passContact)
                    } header: {
                        Text("CONTACTS")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.muted)
                    }
                    .listRowBackground(HPColor.card)

                    Section {
                        inviteRow("💬", "iMessage group chat", "Drops a live potato in the thread. First catch holds it.") {
                            invite(.messages)
                        }
                        inviteRow("⌁", "AirDrop", "Sends the live .hawtpotato file. They become holder when it opens.") {
                            invite(.airDrop)
                        }
                    } header: {
                        Text("INVITE")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.faint)
                    }
                    .listRowBackground(HPColor.card)

                    if !store.inFlightCatchable.isEmpty {
                        Section {
                            ForEach(store.inFlightCatchable) { card in
                                Button {
                                    catchInFlight(card)
                                } label: {
                                    HStack {
                                        PotatoArt(skin: card.skin, size: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(card.callsign.uppercased())
                                                .foregroundStyle(HPColor.ink)
                                            Text("In the air · first CATCH holds it")
                                                .font(.caption2)
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

                    if !store.visibleRecentPlayers.isEmpty {
                        Section {
                            ForEach(store.visibleRecentPlayers) { player in
                                Button {
                                    passPlayedBefore(player)
                                } label: {
                                    HStack {
                                        Text(player.initials)
                                            .font(.caption.bold())
                                            .frame(width: 32, height: 32)
                                            .background(HPColor.potatoOrange, in: Circle())
                                            .foregroundStyle(.black)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(player.displayName)
                                                .foregroundStyle(HPColor.ink)
                                            Text(player.contactPhone == nil
                                                 ? "Swipe to delete. PASS updates iCloud."
                                                 : "Swipe to delete. PASS also opens iMessage.")
                                                .font(.caption2)
                                                .foregroundStyle(HPColor.faint)
                                        }
                                        Spacer()
                                        Text("PASS")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(HPColor.flameYellow)
                                    }
                                }
                                .buttonStyle(.hapticPlain)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button("Delete", role: .destructive) {
                                        store.forgetRecent(player)
                                    }
                                }
                                .playerSafety(player)
                            }
                        } header: {
                            Text("PLAYED BEFORE")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.faint)
                        }
                        .listRowBackground(Color.clear)
                    }

                    if !store.watching.isEmpty {
                        Section {
                            ForEach(store.watching) { card in
                                Button { selectedWatching = card } label: {
                                    HStack {
                                        PotatoArt(skin: card.skin, size: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("#\(card.shortCode)")
                                                .foregroundStyle(HPColor.ink)
                                            Text(card.isPaused
                                                 ? "PAUSED by \(card.pausedBy?.displayName ?? "someone")"
                                                 : "Currently with \(card.currentHolder.displayName)")
                                                .font(.caption)
                                                .foregroundStyle(card.isPaused ? HPColor.potatoOrange : HPColor.faint)
                                        }
                                        Spacer()
                                        Text(card.clockText(at: store.now, isHolder: false))
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(HPColor.flameYellow)
                                    }
                                }
                            }
                        } header: {
                            Text("OPEN POTATOES")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.faint)
                        }
                        .listRowBackground(Color.clear)
                    }

                    if let error {
                        Section {
                            Text(error).foregroundStyle(HPColor.criticalRed).font(.caption)
                        }
                        .listRowBackground(Color.clear)
                    }
                    if let nearbyError = nearby.lastError {
                        Section {
                            Text(nearbyError).foregroundStyle(HPColor.flameYellow).font(.caption)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Lobby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HPColor.nearBlack, for: .navigationBar)
            .sheet(item: $shareDestination) { destination in
                if let card = shareCard ?? store.hottestHeld {
                    SharePotatoView(
                        card: store.potato(card.id) ?? card,
                        senderName: store.me.displayName,
                        destination: destination,
                        recipients: messageRecipients
                    )
                    .ignoresSafeArea()
                }
            }
            .sheet(item: $selectedWatching) { card in
                PotatoDetailView(cardID: card.id)
            }
            .onAppear {
                nearby.start(as: store.me)
                Task { await contacts.refreshIfAuthorized() }
            }
            .overlay {
                if showHandoff, let notice = store.lastHandoff {
                    HandoffNoticeCard(notice: notice) {
                        showHandoff = false
                        store.clearHandoff()
                    }
                }
            }
        }
    }

    private func inviteRow(_ emoji: String, _ title: String, _ subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Text(emoji).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(HPColor.ink)
                    Text(subtitle).font(.caption).foregroundStyle(HPColor.faint)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(HPColor.faint)
            }
        }
    }

    private func passNearby(_ peer: NearbyPeer) {
        guard let card = store.hottestHeld else {
            if store.lastHandoff != nil {
                showHandoff = true
                error = nil
            } else {
                error = "You don't have a potato to pass. Light one on Home first."
            }
            return
        }
        do {
            try store.throwPotato(
                card.id,
                to: peer.player,
                location: store.settings.locationSharing == .hidden ? nil : card.lastLocation
            )
            nearby.throwTo(peer, card: store.potato(card.id) ?? card)
            error = nil
            showHandoff = true
        } catch let potatoError as PotatoError where potatoError == .notHolder {
            showHandoff = store.lastHandoff != nil
            error = showHandoff ? nil : potatoError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func passPlayedBefore(_ player: PlayerRef) {
        guard let card = store.hottestHeld else {
            if store.lastHandoff != nil {
                showHandoff = true
                error = nil
            } else {
                error = "You don't have a potato to pass. Light one on Home first."
            }
            return
        }
        do {
            try store.throwPotato(
                card.id,
                to: player,
                location: store.settings.locationSharing == .hidden ? nil : card.lastLocation
            )
            if let phone = player.contactPhone {
                shareCard = store.potato(card.id) ?? card
                messageRecipients = [phone]
                shareDestination = .messages
            }
            error = nil
            showHandoff = true
        } catch let potatoError as PotatoError where potatoError == .notHolder {
            showHandoff = store.lastHandoff != nil
            error = showHandoff ? nil : potatoError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func catchInFlight(_ card: HotPotatoCard) {
        Task {
            _ = await store.pullRemote(card.id)
            do {
                try store.claimPotato(card.id, location: nil)
                shareCard = store.potato(card.id) ?? card
                messageRecipients = []
                shareDestination = .messages
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func invite(_ destination: PotatoShareDestination) {
        guard let card = store.hottestHeld else {
            error = "Light a potato on Home first."
            return
        }
        do {
            try store.offerPotatoToGroup(card.id)
            shareCard = store.potato(card.id) ?? card
            messageRecipients = []
            shareDestination = destination
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func passContact(_ contact: PhoneContact) {
        ContactDirectory.shared.remember(contact)
        guard let card = store.hottestHeld else {
            error = "You don't have a potato to pass. Light one on Home first."
            return
        }
        do {
            try store.throwPotato(
                card.id,
                to: contact.player,
                location: store.settings.locationSharing == .hidden ? nil : card.lastLocation
            )
            shareCard = store.potato(card.id) ?? card
            messageRecipients = [contact.phone]
            shareDestination = .messages
            error = nil
            showHandoff = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct HandoffNoticeCard: View {
    let notice: HandoffNotice
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(spacing: 14) {
                Text(ProductCanon.voice.safe)
                    .font(HPFont.title(42))
                    .foregroundStyle(HPColor.ink)
                Text("You don't have this potato anymore.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HPColor.ink.opacity(0.88))
                    .multilineTextAlignment(.center)
                Text(ProductCanon.voice.currentlyWith)
                    .foregroundStyle(HPColor.muted)
                Text(notice.recipientName.uppercased())
                    .font(HPFont.name())
                    .foregroundStyle(HPColor.ink)
                Text(notice.callsign.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(HPColor.potatoOrange)
                Button("OK", action: onDismiss)
                    .font(HPFont.action())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(HPColor.potatoOrange, in: Capsule())
                    .padding(.top, 8)
            }
            .padding(28)
            .background(HPColor.nearBlack, in: RoundedRectangle(cornerRadius: 24))
            .padding(24)
        }
        .accessibilityAddTraits(.isModal)
    }
}
