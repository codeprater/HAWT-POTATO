import SwiftUI
import HAWTPotatoCore

struct CreatePotatoSheet: View {
    @Environment(PotatoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onSendToContact: ((HotPotatoCard, PhoneContact) -> Void)? = nil
    @State private var duration = DurationPreset.all.first { $0.seconds == 60 } ?? DurationPreset.all[3]
    @State private var customMinutes = 0
    @State private var customSeconds = 30
    @State private var useCustom = false
    @State private var sharing: LocationSharing = .hidden
    @State private var mode: GameMode = .classic
    @State private var skin: PotatoSkin = .classic
    @State private var nickname = ""
    @State private var note = ""
    @State private var vibe = ""

    var body: some View {
        NavigationStack {
            ZStack {
                HPColor.nearBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("PICK A POTATO")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.muted)
                        RecentContactStrip(players: store.visibleRecentPlayers) { contact in
                            Task { await light(to: contact) }
                        }
                        TextField("Name it (optional)", text: $nickname)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(HPColor.card, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(HPColor.ink)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOUR MESSAGE")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.muted)
                            TextField("20 characters. Make it personal.", text: $note)
                                .textInputAutocapitalization(.sentences)
                                .foregroundStyle(HPColor.ink)
                                .padding()
                                .background(HPColor.card, in: RoundedRectangle(cornerRadius: 14))
                                .onChange(of: note) { _, value in
                                    if value.count > 20 {
                                        note = String(value.prefix(20))
                                    }
                                }
                            HStack {
                                Text("Travels with the potato. They’ll see it when they catch it.")
                                    .font(.caption)
                                    .foregroundStyle(HPColor.faint)
                                Spacer()
                                Text("\(note.count)/20")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(note.count >= 20 ? HPColor.potatoOrange : HPColor.faint)
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("Vibe: panic, smug, feral…", text: $vibe)
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(HPColor.ink)
                            Button("MATCH") {
                                skin = PotatoBrain.skin(forVibe: vibe)
                            }
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(HPColor.flameYellow, in: Capsule())
                        }
                        .padding()
                        .background(HPColor.card, in: RoundedRectangle(cornerRadius: 14))
                        .onChange(of: vibe) { _, value in
                            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                skin = PotatoBrain.skin(forVibe: value)
                            }
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 12)], spacing: 14) {
                            ForEach(PotatoSkin.allCases) { option in
                                Button {
                                    skin = option
                                } label: {
                                    VStack(spacing: 6) {
                                        PotatoArt(skin: option, size: 108, live: skin == option)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(skin == option ? HPColor.potatoOrange : HPColor.card, lineWidth: 3)
                                            )
                                            .shadow(
                                                color: (skin == option ? HPColor.potatoOrange : .clear).opacity(0.55),
                                                radius: 10
                                            )
                                        Text(option.title)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(skin == option ? HPColor.flameYellow : HPColor.muted)
                                            .lineLimit(1)
                                    }
                                }
                                .accessibilityLabel(option.title)
                                .accessibilityAddTraits(skin == option ? .isSelected : [])
                            }
                        }

                        Text("GAME MODE")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.muted)
                        ForEach(GameMode.allCases) { item in
                            Button {
                                mode = item
                            } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .fontWeight(.bold)
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(HPColor.faint)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    if mode == item { Image(systemName: "checkmark") }
                                }
                                .foregroundStyle(HPColor.ink)
                                .padding()
                                .background(
                                    (mode == item ? HPColor.potatoOrange.opacity(0.18) : HPColor.card),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(mode == item ? HPColor.potatoOrange : .clear, lineWidth: 1.5)
                                )
                            }
                        }

                        if mode != .mystery {
                            Text("HOW LONG SHOULD IT LIVE?")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.muted)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(DurationPreset.all) { preset in
                                    chip(preset.title, selected: !useCustom && duration == preset) {
                                        useCustom = false
                                        duration = preset
                                    }
                                }
                                chip("Custom", selected: useCustom) { useCustom = true }
                            }
                            if useCustom {
                                VStack(alignment: .leading, spacing: 12) {
                                    Stepper("\(customMinutes) min", value: $customMinutes, in: 0...180)
                                        .foregroundStyle(HPColor.ink)
                                    Stepper("\(customSeconds) sec", value: $customSeconds, in: 0...59)
                                        .foregroundStyle(HPColor.ink)
                                    Text("Fuse: \(customTotal.hpClock)")
                                        .font(HPFont.timer(22))
                                        .foregroundStyle(HPColor.flameYellow)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SEALED FUSE")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(HPColor.muted)
                                Text("CloudKit rolls a fuse between 20 seconds and 3 minutes. Nobody sees the clock — not even you. Heat color is the only tell.")
                                    .font(.subheadline)
                                    .foregroundStyle(HPColor.muted)
                            }
                            .padding()
                            .background(HPColor.card, in: RoundedRectangle(cornerRadius: 14))
                        }

                        if mode == .suddenDeath {
                            Text("After every catch you have 8 seconds to throw. Miss the window and you're cooked, even if the fuse still has time.")
                                .font(.subheadline)
                                .foregroundStyle(HPColor.flameYellow.opacity(0.9))
                        }

                        Text("SHOW POTATO LOCATION")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.muted)
                        Picker("Location", selection: $sharing) {
                            ForEach(LocationSharing.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        ThrowButton(title: "\(ProductCanon.voice.light) 🔥") {
                            Task { await light() }
                        }
                        .padding(.top, 8)
                        Button("CANCEL") { dismiss() }
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(HPColor.potatoOrange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .buttonStyle(.hapticPlain)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("START A POTATO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(HPColor.potatoOrange)
                }
            }
            .toolbarBackground(HPColor.nearBlack, for: .navigationBar)
        }
        .onAppear { sharing = store.settings.locationSharing }
    }

    private var customTotal: TimeInterval {
        TimeInterval(max(5, customMinutes * 60 + customSeconds))
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(selected ? .black : HPColor.ink)
                .background(selected ? HPColor.potatoOrange : HPColor.card, in: Capsule())
        }
    }

    private func light(to contact: PhoneContact? = nil) async {
        await NotificationDirector.shared.requestIfNeeded()
        let seconds = useCustom ? customTotal : duration.seconds
        let location = await LocationHelper.shared.snapshot(sharing: sharing)
        let card = store.lightPotato(
            duration: seconds,
            locationSharing: sharing,
            location: location,
            gameMode: mode,
            theme: skin.rawValue,
            nickname: nickname,
            note: note
        )
        if let contact {
            ContactDirectory.shared.remember(contact)
            try? store.throwPotato(
                card.id,
                to: contact.player,
                location: store.settings.locationSharing == .hidden ? nil : location
            )
            let live = store.potato(card.id) ?? card
            dismiss()
            DispatchQueue.main.async {
                onSendToContact?(live, contact)
            }
        } else {
            dismiss()
        }
    }
}

struct ThrowSheet: View {
    @Environment(PotatoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let card: HotPotatoCard
    @Bindable private var nearby = NearbyThrowService.shared
    @State private var shareDestination: PotatoShareDestination?
    @State private var messageRecipients: [String] = []
    @State private var contactQuery = ""
    @State private var error: String?
    @State private var safe = false
    @State private var thrownTo: PlayerRef?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(heat: card.heat(at: store.now))
                if safe, let thrownTo {
                    VStack(spacing: 16) {
                        Text(ProductCanon.voice.safe)
                            .font(HPFont.title(42))
                            .foregroundStyle(HPColor.ink)
                        Text("You don't have this potato anymore.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HPColor.ink.opacity(0.88))
                        Text(ProductCanon.voice.currentlyWith)
                            .foregroundStyle(HPColor.muted)
                        Text(thrownTo.displayName.uppercased())
                            .font(HPFont.name())
                            .foregroundStyle(HPColor.ink)
                        Text(liveClock)
                            .font(HPFont.timer(40))
                            .foregroundStyle(HPColor.flameYellow)
                        Button("WATCH POTATO") { dismiss() }
                            .font(HPFont.action())
                            .foregroundStyle(HPColor.potatoOrange)
                        Button("BACK") { dismiss() }
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(HPColor.muted)
                    }
                } else {
                    ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("THROW THE POTATO")
                            .font(HPFont.title(28))
                            .foregroundStyle(HPColor.ink)
                        Text(card.callsign.uppercased())
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.potatoOrange)
                        actionRow("💬", "iMessage / group chat") { launchShare(.messages) }
                        Text(PotatoBrain.groupThrowWarning())
                            .font(.caption)
                            .foregroundStyle(HPColor.flameYellow.opacity(0.85))
                        Text("CONTACTS")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.faint)
                        ContactPickList(query: $contactQuery, limit: 12) { contact in
                            messageContact(contact)
                        }
                        actionRow("⚡", "Nearby") { passNearbyFromSheet() }
                        actionRow("⌁", "AirDrop") { launchShare(.airDrop) }
                        let picks = store.dumpPicks(nearby: nearby.peers.filter { !store.isBlocked($0.player) }.map(\.player))
                        if !picks.isEmpty {
                            Text("DUMP TO THEM")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.faint)
                            ForEach(picks.prefix(4)) { pick in
                                Button {
                                    if let peer = nearby.peers.first(where: { $0.playerID == pick.player.id }) {
                                        send(to: pick.player) {
                                            nearby.throwTo(peer, card: store.potato(card.id) ?? card)
                                        }
                                    } else {
                                        send(to: pick.player)
                                    }
                                } label: {
                                    HStack {
                                        Text(pick.player.initials)
                                            .font(.caption.bold())
                                            .frame(width: 32, height: 32)
                                            .background(HPColor.flameYellow, in: Circle())
                                            .foregroundStyle(.black)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(pick.player.displayName)
                                                .foregroundStyle(HPColor.ink)
                                            Text(pick.reason)
                                                .font(.caption2)
                                                .foregroundStyle(HPColor.potatoOrange)
                                        }
                                        Spacer()
                                        Text("DUMP")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(HPColor.potatoOrange, in: Capsule())
                                    }
                                }
                                .playerSafety(pick.player)
                            }
                        }
                        if !store.visibleRecentPlayers.isEmpty {
                            Text("PLAYED BEFORE")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.faint)
                            ForEach(store.visibleRecentPlayers) { player in
                                Button {
                                    send(to: player)
                                } label: {
                                    HStack {
                                        Text(player.initials)
                                            .font(.caption.bold())
                                            .frame(width: 32, height: 32)
                                            .background(HPColor.potatoOrange, in: Circle())
                                            .foregroundStyle(.black)
                                        Text(player.displayName)
                                            .foregroundStyle(HPColor.ink)
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .playerSafety(player)
                            }
                        }
                        if nearby.peers.filter({ !store.isBlocked($0.player) }).isEmpty {
                            Text("Looking for nearby players. Keep HAWT POTATO open on both phones.")
                                .font(.caption)
                                .foregroundStyle(HPColor.faint)
                        } else {
                            ForEach(nearby.peers.filter { !store.isBlocked($0.player) }) { peer in
                                Button {
                                    send(to: peer.player) {
                                        nearby.throwTo(peer, card: store.potato(card.id) ?? card)
                                    }
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(nearby.isConnected(peer) ? Color.green : Color.yellow)
                                            .frame(width: 8, height: 8)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(peer.displayName).foregroundStyle(HPColor.ink)
                                            Text(nearby.isConnected(peer) ? "Ready · tap PASS" : "Connecting…")
                                                .font(.caption2)
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
                                    .padding(12)
                                    .background(HPColor.card, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .playerSafety(peer.player)
                            }
                        }
                        Button("Throw into this iMessage chat") {
                            launchShare(.messages)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HPColor.muted)
                        if let error {
                            Text(error).foregroundStyle(HPColor.criticalRed).font(.caption)
                        }
                        if let nearbyError = nearby.lastError {
                            Text(nearbyError).foregroundStyle(HPColor.flameYellow).font(.caption)
                        }
                        Button("BACK") { dismiss() }
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(HPColor.muted)
                    }
                    .padding(20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(HPColor.potatoOrange)
                }
            }
        }
        .onAppear {
            nearby.start(as: store.me)
        }
        .sheet(item: $shareDestination) { destination in
            SharePotatoView(
                card: store.potato(card.id) ?? card,
                senderName: store.me.displayName,
                destination: destination,
                recipients: messageRecipients
            )
            .ignoresSafeArea()
        }
    }

    private var liveClock: String {
        let live = store.potato(card.id) ?? card
        return live.clockText(at: store.now, isHolder: false)
    }

    private func actionRow(_ emoji: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(emoji).frame(width: 36)
                Text(title).font(.headline).foregroundStyle(HPColor.ink)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(HPColor.faint)
            }
            .padding()
            .background(HPColor.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func launchShare(_ destination: PotatoShareDestination) {
        do {
            try store.offerPotatoToGroup(card.id)
            messageRecipients = []
            shareDestination = destination
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func messageContact(_ contact: PhoneContact) {
        ContactDirectory.shared.remember(contact)
        send(to: contact.player)
        messageRecipients = [contact.phone]
        shareDestination = .messages
    }

    private func send(to player: PlayerRef, extra: (() -> Void)? = nil) {
        do {
            try store.throwPotato(card.id, to: player, location: store.settings.locationSharing == .hidden ? nil : store.potato(card.id)?.lastLocation)
            thrownTo = player
            extra?()
            withAnimation { safe = true }
        } catch let potatoError as PotatoError where potatoError == .notHolder {
            thrownTo = player
            withAnimation { safe = true }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func passNearbyFromSheet() {
        let peers = nearby.peers.filter { !store.isBlocked($0.player) }
        if let only = peers.first, peers.count == 1 {
            send(to: only.player) {
                nearby.throwTo(only, card: store.potato(card.id) ?? card)
            }
        } else if peers.isEmpty {
            error = "Looking for nearby players. Keep HAWT POTATO open on both phones."
        } else {
            error = "Tap PASS next to who should get it."
        }
    }
}
