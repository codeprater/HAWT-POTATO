import WidgetKit
import SwiftUI
import HAWTPotatoCore

struct PotatoEntry: TimelineEntry {
    let date: Date
    let card: HotPotatoCard?
    let meName: String
}

struct PotatoProvider: TimelineProvider {
    func placeholder(in context: Context) -> PotatoEntry {
        PotatoEntry(date: .now, card: nil, meName: "You")
    }

    func getSnapshot(in context: Context, completion: @escaping (PotatoEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PotatoEntry>) -> Void) {
        let entry = load()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30))))
    }

    private func load() -> PotatoEntry {
        let state = LocalPersistence().load()
        let me = state.identity
        let holding = state.potatoes.filter { card in
            guard let me else { return false }
            return card.isHeld(by: me) && card.status != .exploded
        }.sorted { $0.lethalDeadline() < $1.lethalDeadline() }
        return PotatoEntry(date: .now, card: holding.first ?? state.potatoes.first, meName: me?.displayName ?? "You")
    }
}

struct PotatoWidgetView: View {
    var entry: PotatoEntry

    var body: some View {
        ZStack {
            HPColor.nearBlack
            if let card = entry.card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("🥔 HAWT POTATO")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(HPColor.potatoOrange)
                    if card.status == .exploded {
                        Text("💥 EXPLODED")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("ON \(card.explosion?.loser.displayName.uppercased() ?? "")")
                            .foregroundStyle(.white.opacity(0.7))
                    } else if card.isHeld(by: PlayerRef(id: "", displayName: entry.meName)) || true {
                        Text(card.isHeld(by: PlayerRef(id: card.currentHolder.id, displayName: card.currentHolder.displayName)) ? "YOU HAVE IT" : "Currently with \(card.currentHolder.displayName)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(card.clockText(at: entry.date, isHolder: true))
                            .font(card.hidesClock ? .headline.weight(.black) : .system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(HPColor.flameYellow)
                            .minimumScaleFactor(0.6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            } else {
                VStack {
                    Text("🥔")
                    Text("Time To Cook!!")
                        .foregroundStyle(.white)
                }
            }
        }
        .containerBackground(for: .widget) { HPColor.nearBlack }
    }
}

@main
struct HawtPotatoWidgets: WidgetBundle {
    var body: some Widget {
        HawtPotatoWidget()
        PotatoLiveActivity()
    }
}

struct HawtPotatoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HAWTPotatoWidget", provider: PotatoProvider()) { entry in
            PotatoWidgetView(entry: entry)
        }
        .configurationDisplayName("HAWT POTATO")
        .description("See the potato you're holding.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
