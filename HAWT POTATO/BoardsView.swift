import SwiftUI
import UIKit
import HAWTPotatoCore

struct BoardsView: View {
    @Environment(PotatoStore.self) private var store
    @State private var scope: BoardScope = .friends
    @State private var period: BoardPeriod = .allTime
    @State private var selected: HotPotatoCard?
    @State private var shareCard: HotPotatoCard?
    @State private var savedNotice = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(branded: true)
                List {
                    Section {
                        Text(store.weeklyStory)
                            .foregroundStyle(HPColor.ink)
                            .font(.subheadline.weight(.semibold))
                    } header: {
                        Text("THIS WEEK")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.faint)
                    }
                    .listRowBackground(HPColor.card)

                    if let profile = store.profile {
                        Section {
                            youRow("🏆 Survival", "\(Int(profile.survivalRate * 100))%")
                            youRow("🥔 Received", "\(profile.received)")
                            youRow("🔥 Passed", "\(profile.passed)")
                            youRow("💥 Cooked on you", "\(profile.explodedOnMe)")
                            youRow("⚡ Fastest dump", profile.fastestPass?.hpClock ?? "—")
                            youRow("⏱ Longest hold", profile.longestSafeHold?.hpClock ?? "—")
                            youRow("🔁 Throws", "\(profile.totalThrows)")
                        } header: {
                            Text("YOU")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.faint)
                        }
                        .listRowBackground(HPColor.card)
                    }

                    Section {
                        if store.history.isEmpty {
                            Text("Finished potatoes land here. Swipe to save, send, or delete.")
                                .foregroundStyle(HPColor.faint)
                        } else {
                            ForEach(store.history) { card in
                                Button {
                                    selected = card
                                } label: {
                                    PotatoListRow(card: card, exploded: true, now: store.now)
                                }
                                .buttonStyle(.hapticPlain)
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        saveToPhotos(card)
                                    } label: {
                                        Label("Save", systemImage: "square.and.arrow.down")
                                    }
                                    .tint(HPColor.potatoOrange)
                                    Button {
                                        shareCard = card
                                    } label: {
                                        Label("Sticker", systemImage: "square.on.square")
                                    }
                                    .tint(HPColor.flameYellow)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.deletePotato(card.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("HISTORY")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.faint)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Section {
                        Picker("Who", selection: $scope) {
                            ForEach(BoardScope.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        Picker("When", selection: $period) {
                            ForEach(BoardPeriod.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(Color.clear)

                    board("SURVIVAL", rows.sorted { $0.survivalRate > $1.survivalRate }, value: { "\(Int($0.survivalRate * 100))%" })
                    board("MOST PASSES", rows.sorted { $0.passed > $1.passed }, value: { "\($0.passed)" })
                    board("FASTEST DUMP", rows.sorted { ($0.fastestPass ?? .greatestFiniteMagnitude) < ($1.fastestPass ?? .greatestFiniteMagnitude) }, value: { $0.fastestPass?.hpClock ?? "—" })
                    board("SHAME BOARD", rows.sorted { $0.cooked > $1.cooked }, value: { "\($0.cooked) cooked" })

                    if !cookedHistory.isEmpty {
                        Section {
                            ForEach(cookedHistory) { card in
                                Button { selected = card } label: {
                                    HStack {
                                        Text("💥")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text((card.explosion?.loser.displayName ?? card.currentHolder.displayName).uppercased())
                                                .foregroundStyle(HPColor.ink)
                                            Text("#\(card.shortCode) · \(card.passCount) passes")
                                                .font(.caption)
                                                .foregroundStyle(HPColor.faint)
                                        }
                                        Spacer()
                                        Text(card.gameMode.title)
                                            .font(.caption2.weight(.heavy))
                                            .foregroundStyle(HPColor.potatoOrange)
                                    }
                                }
                            }
                        } header: {
                            Text("COOKED")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HPColor.faint)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                if savedNotice {
                    Text("SAVED TO PHOTOS")
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.72), in: Capsule())
                        .foregroundStyle(HPColor.flameYellow)
                        .transition(.opacity)
                }
            }
            .navigationTitle("Boards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HPColor.nearBlack, for: .navigationBar)
            .sheet(item: $selected) { card in
                PotatoDetailView(cardID: card.id)
            }
            .sheet(item: $shareCard) { card in
                SharePotatoView(
                    card: card,
                    senderName: store.me.displayName,
                    destination: .send
                )
                .ignoresSafeArea()
            }
        }
    }

    private func saveToPhotos(_ card: HotPotatoCard) {
        let image = PotatoShareArtwork.image(for: card, senderName: store.me.displayName)
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation { savedNotice = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { savedNotice = false }
        }
    }

    private var rows: [BoardRow] {
        BoardRow.build(from: store, scope: scope, period: period, nearbyIDs: Set(NearbyThrowService.shared.peers.map(\.playerID)))
    }

    private var cookedHistory: [HotPotatoCard] {
        let start = period.start
        return store.history.filter { card in
            guard let at = card.explosion?.explodedAt else { return period == .allTime }
            return at >= start
        }
    }

    private func youRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(HPColor.muted)
            Spacer()
            Text(value).fontWeight(.bold).foregroundStyle(HPColor.ink)
        }
    }

    private func board(_ title: String, _ ranked: [BoardRow], value: @escaping (BoardRow) -> String) -> some View {
        Section {
            if ranked.isEmpty {
                Text("No scores yet. Throw a potato.")
                    .foregroundStyle(HPColor.faint)
            } else {
                ForEach(Array(ranked.prefix(8).enumerated()), id: \.element.id) { index, row in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.flameYellow)
                            .frame(width: 18)
                        Text(row.player.displayName)
                            .foregroundStyle(HPColor.ink)
                        Spacer()
                        Text(value(row))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HPColor.muted)
                    }
                }
            }
        } header: {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(HPColor.faint)
        }
        .listRowBackground(Color.clear)
    }
}

enum BoardScope: String, CaseIterable, Identifiable {
    case friends, nearby, circle
    var id: String { rawValue }
    var title: String {
        switch self {
        case .friends: "Friends"
        case .nearby: "Nearby"
        case .circle: "Circle"
        }
    }
}

enum BoardPeriod: String, CaseIterable, Identifiable {
    case week, allTime
    var id: String { rawValue }
    var title: String { self == .week ? "This week" : "All time" }
    var start: Date {
        switch self {
        case .allTime: Date.distantPast
        case .week: Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        }
    }
}

struct BoardRow: Identifiable {
    var id: String { player.id }
    var player: PlayerRef
    var passed: Int
    var cooked: Int
    var received: Int
    var fastestPass: TimeInterval?
    var survivalRate: Double

    static func build(from store: PotatoStore, scope: BoardScope, period: BoardPeriod, nearbyIDs: Set<String>) -> [BoardRow] {
        let start = period.start
        var stats: [String: BoardRow] = [:]

        func bucket(_ player: PlayerRef) -> BoardRow {
            stats[player.id] ?? BoardRow(player: player, passed: 0, cooked: 0, received: 0, fastestPass: nil, survivalRate: 1)
        }

        for card in store.potatoes {
            for event in card.history where event.at >= start {
                var row = bucket(event.player)
                switch event.action {
                case .received, .claimed:
                    row.received += 1
                case .passed:
                    row.passed += 1
                    if row.fastestPass == nil || event.remaining < (row.fastestPass ?? event.remaining) {
                        row.fastestPass = max(0, card.duration - event.remaining)
                    }
                case .exploded:
                    row.cooked += 1
                case .created, .paused, .resumed:
                    break
                }
                stats[event.player.id] = row
            }
        }

        if let me = store.identity, let profile = store.profile, period == .allTime {
            var mine = stats[me.id] ?? BoardRow(player: me, passed: 0, cooked: 0, received: 0, fastestPass: nil, survivalRate: 1)
            mine.player = me
            mine.received = max(mine.received, profile.received)
            mine.passed = max(mine.passed, profile.passed)
            mine.cooked = max(mine.cooked, profile.explodedOnMe)
            mine.fastestPass = profile.fastestPass ?? mine.fastestPass
            stats[me.id] = mine
        }

        for id in stats.keys {
            let row = stats[id]!
            let denom = max(1, row.received)
            stats[id]?.survivalRate = Double(max(0, denom - row.cooked)) / Double(denom)
        }

        let allowed: Set<String>?
        switch scope {
        case .friends:
            allowed = Set(store.visibleRecentPlayers.map(\.id) + [store.me.id])
        case .nearby:
            allowed = nearbyIDs.union([store.me.id])
        case .circle:
            allowed = nil
        }

        return stats.values
            .filter { !store.isBlocked($0.player) }
            .filter { allowed == nil || allowed!.contains($0.player.id) }
    }
}
