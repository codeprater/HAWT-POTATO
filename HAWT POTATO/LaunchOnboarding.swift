import SwiftUI
import HAWTPotatoCore

struct LaunchView: View {
    var onFinished: () -> Void
    @State private var potato = false
    @State private var flame = false
    @State private var title = false

    var body: some View {
        ZStack {
            HPColor.nearBlack.ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    PotatoArt(skin: .classic, size: 128)
                    if flame {
                        Text("🔥")
                            .font(.system(size: 42))
                            .offset(y: -58)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(potato ? 1 : 0.4)
                .opacity(potato ? 1 : 0)
                if title {
                    Text("HAWT POTATO")
                        .font(HPFont.title(36))
                        .foregroundStyle(HPColor.ink)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.32)) { potato = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                withAnimation(.easeOut(duration: 0.2)) { flame = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
                withAnimation(.easeOut(duration: 0.22)) { title = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
                onFinished()
            }
        }
        .accessibilityLabel("HAWT POTATO")
    }
}

struct OnboardingView: View {
    @Environment(PotatoStore.self) private var store
    @State private var page = 0
    @State private var name = ""
    @State private var isThirteenOrOlder = false
    @State private var acceptedLegal = false

    private var canStart: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isThirteenOrOlder && acceptedLegal
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HPColor.nearBlack.ignoresSafeArea()
                VStack(spacing: 28) {
                    TabView(selection: $page) {
                        onboard(
                            title: "MEET THE POTATO",
                            emoji: "🔥🥔",
                            copy: "This isn't just a game.\nIt's a potato you send to people.",
                            tag: 0
                        )
                        onboard(
                            title: "THROW IT",
                            emoji: "🥔 ──────→",
                            copy: "Send it through Messages or to someone nearby.",
                            tag: 1
                        )
                        onboard(
                            title: "DON'T GET CAUGHT",
                            emoji: "00:08",
                            copy: "Get rid of it before time runs out.",
                            tag: 2,
                            timerStyle: true
                        )
                        onboard(
                            title: "FOLLOW IT",
                            emoji: "Courtney → Mike → Lisa → 💥",
                            copy: "Watch your potato travel and see who gets caught.",
                            tag: 3
                        )
                        nameCard.tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))

                    Button(page < 4 ? "Continue →" : ProductCanon.voice.startThrowing) {
                        if page < 4 {
                            page += 1
                        } else if canStart {
                            store.completeOnboarding(displayName: name)
                        }
                    }
                    .font(HPFont.action())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        (page < 4 || canStart ? HPColor.potatoOrange : HPColor.card),
                        in: Capsule()
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .disabled(page >= 4 && !canStart)
                }
            }
        }
    }

    private func onboard(title: String, emoji: String, copy: String, tag: Int, timerStyle: Bool = false) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Text(title)
                .font(HPFont.title(32))
                .foregroundStyle(HPColor.ink)
                .multilineTextAlignment(.center)
            Text(emoji)
                .font(timerStyle ? HPFont.timer(54) : .system(size: 40, weight: .bold))
                .foregroundStyle(timerStyle ? HPColor.flameYellow : HPColor.ink)
                .multilineTextAlignment(.center)
            Text(copy)
                .font(HPFont.body())
                .foregroundStyle(HPColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
        .tag(tag)
    }

    private var nameCard: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("WHAT SHOULD WE CALL YOU?")
                .font(HPFont.title(28))
                .foregroundStyle(HPColor.ink)
                .multilineTextAlignment(.center)
            TextField("Display name", text: $name)
                .textInputAutocapitalization(.words)
                .padding()
                .background(HPColor.card, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(HPColor.ink)
                .padding(.horizontal, 28)
            Text("No password. iCloud keeps your potatoes in sync. Other players can see this name.")
                .font(.caption)
                .foregroundStyle(HPColor.faint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Toggle(isOn: $isThirteenOrOlder) {
                Text("I am \(ProductCanon.minimumAge) or older")
                    .foregroundStyle(HPColor.ink)
            }
            .tint(HPColor.potatoOrange)
            .padding(.horizontal, 28)
            Toggle(isOn: $acceptedLegal) {
                Text("I agree to the Terms and Privacy Policy")
                    .foregroundStyle(HPColor.ink)
            }
            .tint(HPColor.potatoOrange)
            .padding(.horizontal, 28)
            HStack(spacing: 16) {
                NavigationLink("Read Terms") {
                    LegalDocumentView(title: "Terms", bodyText: LegalCopy.terms)
                }
                NavigationLink("Read Privacy") {
                    LegalDocumentView(title: "Privacy", bodyText: LegalCopy.privacy)
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(HPColor.potatoOrange)
            Spacer()
        }
    }
}

struct HowToPlayView: View {
    var body: some View {
        ZStack {
            HPColor.nearBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    playCard("The potato is the game", "One live card. One holder. Home says Time To Cook!! until you light one. Ignore it and the fuse still runs. That’s the game, not a bug.")
                    playCard("Start a potato", "Tap + START A POTATO. Name it, write a 20-character message, pick a face, then light it. Classic shows the clock. Mystery hides it. Sudden Death gives you 8 seconds after every catch. CANCEL on a potato you just lit (and have not thrown) puts it out.")
                    playCard("Send it fast", "Recent Contacts sit above Start a Potato. Tap a person to light and iMessage them. Tap Contacts to open your phone’s contact list. Allow Contacts so we can address the message. Names and numbers stay on this device.")
                    playCard("Throw it", "Nearby: keep both apps open, tap PASS. iMessage: throw into a chat or a group thread. AirDrop: they open the live file. Played Before: tap PASS. If we have their number, iMessage opens too. Swipe a Played Before row to delete them from the list.")
                    playCard("App and iMessage are the same game", "The live potato lives in iCloud. The chat bubble is a CATCH button plus a link, not a second potato. First CATCH — in the app under IN THE AIR, or in iMessage — holds it. After you catch, throw it back into the same thread so the group stays in the loop.")
                    playCard("Catch it", "If someone passes you one, you get the slam screen, a sound, and a vibrate. A red badge lands on Home and the app icon until you throw it or it cooks you.")
                    playCard("Pause it", "Open Find My Potato, tap the card, then PAUSE. The fuse freezes for everyone and the card says who paused it, so nobody can hide a timeout. RESUME starts the same time left. You cannot throw while it is paused.")
                    playCard("Find My Potato", "Potatoes you lit or passed stay here. Tap one to see who has it, the journey, and the map if location was shared. PAUSE and RESUME live on that card.")
                    playCard("Last 10 seconds", "Every phone that still has that card hears the tick. At 3 seconds it vibrates with the tick. At zero, every device shakes: THEY ARE COOKED!")
                    playCard("Stay safe", "Swipe Block or Report on anyone in Lobby. Swipe Played Before to delete. Light or Dark is in Settings → Look. Light is cream and light brown.")
                }
                .padding(20)
            }
        }
        .navigationTitle("How to play")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HPColor.nearBlack, for: .navigationBar)
        
    }

    private func playCard(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(HPColor.ink)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(HPColor.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
