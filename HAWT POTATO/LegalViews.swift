import SwiftUI
import HAWTPotatoCore

enum LegalCopy {
    static let privacy = """
    HAWT POTATO Privacy Policy
    Last updated: August 15, 2026

    HAWT POTATO is a sendable potato game. We do not sell your data and we do not use tracking pixels, advertising SDKs, or App Tracking Transparency.

    What we collect
    • Display name you type in. Other players can see it on potatoes you throw.
    • A player ID from iCloud (CloudKit) so the app can tell who is holding a potato.
    • Potato cards you light or catch, including the fuse deadline, game mode, and pass history. These are stored on your device and in iCloud public records so the timer stays honest if someone is offline.
    • Approximate or precise location only if you turn on potato location sharing. Default is Hidden. Location is attached to that potato’s journey for other players in that potato only.
    • Photos only if you swipe Save in History. We add an image to your library; we do not read your photo library.
    • Nearby / Bluetooth / local network, only while the app is open, to find phones next to you.
    • Contacts stay on this device. We read names and phone numbers only to address an iMessage when you tap someone in Lobby or Throw. We do not upload your contacts.

    What we do not collect
    • We do not collect email, payment info, or analytics for advertising.
    • We do not track you across other companies’ apps or websites.

    Sharing
    Potato cards and display names are shared with the people you throw to, and with anyone watching that potato. iCloud/CloudKit is provided by Apple. We do not sell personal information.

    Your choices
    • Keep location Hidden (default).
    • Block a player in Lobby or Settings so they no longer appear in Nearby / Played Before.
    • Report a player from Lobby or Settings. Reports go to \(ProductCanon.supportEmail).
    • Delete All Data in Settings. This clears the game from this device and deletes potato records you created, when iCloud allows it.

    Children
    HAWT POTATO is not directed at children under \(ProductCanon.minimumAge). You must confirm you are \(ProductCanon.minimumAge) or older before playing.

    Contact
    Courtney Prater
    Prater10@icloud.com
    \(ProductCanon.supportEmail)
    \(ProductCanon.privacyURL.absoluteString)

    \(ProductCanon.copyrightLine)
    """

    static let terms = """
    HAWT POTATO Terms of Use
    Last updated: August 15, 2026

    By using HAWT POTATO you agree to these terms.

    The game
    HAWT POTATO is a real-time throw-and-catch game. One potato has one holder. If you ignore a potato until the fuse hits zero, you get cooked. That is the game, not a defect.

    Your name
    Display names are visible to other players. Do not use names that are hateful, sexual involving minors, threatening, or impersonating someone else. We may replace a name that breaks this rule.

    Safety
    You can block and report other players. Do not use the app to harass people. We may remove content or restrict play that breaks these terms or Apple’s rules.

    Nearby, Messages, AirDrop
    Nearby uses Bluetooth and your local network while the app is open. Messages sends a picture and a catch link because iMessage cannot carry the live potato file. AirDrop sends the live potato file. Played Before updates iCloud; the other phone sees it when they open the app.

    Disclaimer
    The app is provided as-is. CloudKit, Bluetooth, and Messages can fail if a phone is offline, in Low Power Mode, or missing iCloud. The potato’s stored deadline is still the referee.

    Contact
    Courtney Prater
    Prater10@icloud.com
    \(ProductCanon.supportEmail)

    \(ProductCanon.copyrightLine)
    """
}

struct LegalDocumentView: View {
    let title: String
    let bodyText: String

    var body: some View {
        ZStack {
            ScreenBackground(branded: true)
            ScrollView {
                Text(bodyText)
                    .font(.body)
                    .foregroundStyle(HPColor.ink)
                    .padding(20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HPColor.nearBlack, for: .navigationBar)
        
    }
}

struct BlockedPlayersView: View {
    @Environment(PotatoStore.self) private var store

    var body: some View {
        ZStack {
            ScreenBackground(branded: true)
            List {
                if store.blockedPlayers.isEmpty {
                    Text("Nobody blocked.")
                        .foregroundStyle(HPColor.muted)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(store.blockedPlayers) { player in
                        HStack {
                            Text(player.initials)
                                .font(.caption.bold())
                                .frame(width: 32, height: 32)
                                .background(HPColor.potatoOrange, in: Circle())
                                .foregroundStyle(.black)
                            Text(player.displayName)
                                .foregroundStyle(HPColor.ink)
                            Spacer()
                            Button("Unblock") { store.unblock(player) }
                                .foregroundStyle(HPColor.potatoOrange)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Blocked")
        
    }
}

extension View {
    func playerSafety(_ player: PlayerRef) -> some View {
        modifier(PlayerSafetyModifier(player: player))
    }
}

private struct PlayerSafetyModifier: ViewModifier {
    @Environment(PotatoStore.self) private var store
    @Environment(\.openURL) private var openURL
    let player: PlayerRef

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Block", role: .destructive) {
                    store.block(player)
                }
                Button("Report") {
                    openURL(ProductCanon.reportMailURL(
                        player: player,
                        reporter: store.me,
                        harassmentLikely: store.repeatDumper(includeDismissed: true)?.id == player.id
                    ))
                    store.block(player)
                }
                .tint(HPColor.flameYellow)
            }
            .contextMenu {
                Button("Block \(player.displayName)", role: .destructive) {
                    store.block(player)
                }
                Button("Report \(player.displayName)") {
                    openURL(ProductCanon.reportMailURL(
                        player: player,
                        reporter: store.me,
                        harassmentLikely: store.repeatDumper(includeDismissed: true)?.id == player.id
                    ))
                    store.block(player)
                }
            }
    }
}
