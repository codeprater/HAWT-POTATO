import SwiftUI
import HAWTPotatoCore

struct MainTabView: View {
    @Environment(PotatoStore.self) private var store
    @State private var throwingCard: HotPotatoCard?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(onThrow: { throwingCard = $0 })
                .tabItem { Label("Home", systemImage: "flame.fill") }
                .badge(store.homeBadgeCount)
                .tag(0)
            LobbyView(
                onThrow: { throwingCard = $0 },
                onOpenHome: { selectedTab = 0 }
            )
            .tabItem { Label("Lobby", systemImage: "person.3.fill") }
            .tag(1)
            BoardsView()
                .tabItem { Label("Boards", systemImage: "trophy.fill") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(HPColor.potatoOrange)
        .toolbarBackground(HPColor.nearBlack, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .buttonStyle(.haptic)
        .sheet(item: $throwingCard) { card in
            ThrowSheet(card: card)
                .buttonStyle(.haptic)
        }
        .onChange(of: store.pendingThrowID) { _, _ in
            if let card = store.consumePendingThrow() {
                throwingCard = card
            }
        }
    }
}
