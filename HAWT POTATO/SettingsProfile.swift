import SwiftUI
import HAWTPotatoCore

struct SettingsView: View {
    @Environment(PotatoStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var nameDraft = ""
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(branded: true)
                Form {
                    Section("ACCOUNT") {
                        TextField("Display name", text: $nameDraft)
                            .textInputAutocapitalization(.words)
                        Button("Save name") {
                            store.updateDisplayName(nameDraft)
                            nameDraft = store.me.displayName
                            NearbyThrowService.shared.start(as: store.me)
                        }
                        .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Section {
                        NavigationLink("Blocked players") {
                            BlockedPlayersView()
                        }
                        Button("Report a player") {
                            openURL(ProductCanon.supportMailURL())
                        }
                    } header: {
                        Text("SAFETY")
                    } footer: {
                        Text("Swipe Block or Report on anyone in Lobby. Reports email \(ProductCanon.supportEmail).")
                    }
                    Section {
                        Button("Delete All Data", role: .destructive) {
                            confirmDelete = true
                        }
                    } header: {
                        Text("YOUR DATA")
                    } footer: {
                        Text("Clears potatoes, name, and history on this device and deletes potatoes you created from iCloud when possible. There is no login to delete — this is the reset.")
                    }
                    Section {
                        Toggle("Sound Effects", isOn: bind(\.soundEffects))
                        Toggle("Haptics", isOn: bind(\.haptics))
                        Toggle("Countdown Sound", isOn: bind(\.countdownSounds))
                    } header: {
                        Text("GAMEPLAY")
                    } footer: {
                        Text("Buttons click when you press them. Catching a potato plays a sound and vibrates. At 10 seconds the fuse ticks on every phone in the game. When it blows, every device vibrates: THEY ARE COOKED!")
                    }
                    Section {
                        Picker("Appearance", selection: bind(\.appearance)) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    } header: {
                        Text("LOOK")
                    } footer: {
                        Text("Light is cream and light brown. Dark stays charcoal and flame.")
                    }
                    Section("LOCATION") {
                        Picker("Share Potato Location", selection: bind(\.locationSharing)) {
                            ForEach(LocationSharing.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    }
                    Section("NOTIFICATIONS") {
                        Toggle("Received Potatoes", isOn: bind(\.notifyReceived))
                        Toggle("Timer Warnings", isOn: bind(\.notifyWarnings))
                        Toggle("Movement Updates", isOn: bind(\.notifyMovement))
                        Toggle("Explosion Results", isOn: bind(\.notifyExplosion))
                    }
                    Section("ABOUT") {
                        NavigationLink("How to play") {
                            HowToPlayView()
                        }
                        Text("One potato, one holder. App and iMessage share the same iCloud card. Nearby jumps phone-to-phone. Group chat: first CATCH wins. Pause is public. Ignore it and you're cooked.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Notifications only fire for the person who caught it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        NavigationLink("Privacy Policy") {
                            LegalDocumentView(title: "Privacy", bodyText: LegalCopy.privacy)
                        }
                        NavigationLink("Terms of Use") {
                            LegalDocumentView(title: "Terms", bodyText: LegalCopy.terms)
                        }
                        Button("Email support") {
                            openURL(ProductCanon.supportMailURL())
                        }
                        Link("Privacy on the web", destination: ProductCanon.privacyURL)
                        Link("Terms on the web", destination: ProductCanon.termsURL)
                        Text("Version 2.0")
                        Text("2026 Courtney & Kourtney Prater")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .tint(HPColor.potatoOrange)
            }
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear { nameDraft = store.me.displayName }
            .alert("Delete all HAWT POTATO data?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    store.resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone. You will go back to the start screen.")
            }
        }
    }

    private func bind<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { value in
                store.updateSettings { $0[keyPath: keyPath] = value }
            }
        )
    }
}

struct ProfileView: View {
    @Environment(PotatoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(branded: true)
                ScrollView {
                    VStack(spacing: 22) {
                        ZStack(alignment: .bottomTrailing) {
                            PotatoVisual(
                                heat: .hot,
                                exploded: false,
                                reduceMotion: false,
                                size: 200,
                                skin: avatarSkin
                            )
                            Text(store.me.initials)
                                .font(.caption.weight(.black))
                                .frame(width: 44, height: 44)
                                .background(HPColor.flameYellow, in: Circle())
                                .foregroundStyle(.black)
                                .offset(x: -8, y: -8)
                        }
                        Text(store.me.displayName.uppercased())
                            .font(HPFont.name())
                            .foregroundStyle(HPColor.ink)
                        if let profile = store.profile {
                            VStack(spacing: 0) {
                                stat("🥔 Received", "\(profile.received)")
                                stat("🔥 Successfully Passed", "\(profile.passed)")
                                stat("💥 Exploded On Me", "\(profile.explodedOnMe)")
                                stat("⚡ Fastest Pass", profile.fastestPass?.hpClock ?? "—")
                                stat("⏱ Longest Safe Hold", profile.longestSafeHold?.hpClock ?? "—")
                                stat("🔁 Total Throws", "\(profile.totalThrows)")
                                stat("🏆 Survival Rate", "\(Int(profile.survivalRate * 100))%")
                            }
                            .padding(18)
                            .background(HPColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(HPColor.potatoOrange.opacity(0.35), lineWidth: 1)
                            )
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Profile")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var avatarSkin: PotatoSkin {
        let skins = store.potatoes.map(\.skin)
        let counted = Dictionary(grouping: skins, by: { $0 }).mapValues(\.count)
        return counted.max(by: { $0.value < $1.value })?.key ?? .classic
    }

    private func stat(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(HPColor.muted)
            Spacer()
            Text(value).fontWeight(.bold).foregroundStyle(HPColor.ink)
        }
        .padding(.vertical, 8)
    }
}
