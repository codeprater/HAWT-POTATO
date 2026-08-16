import WidgetKit
import SwiftUI
import ActivityKit
import HAWTPotatoCore

struct PotatoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PotatoLiveAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(HPColor.nearBlack)
                .activitySystemActionForegroundColor(HPColor.flameYellow)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("🥔")
                        .font(.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.clockText)
                        .font(.headline.monospacedDigit().weight(.bold))
                        .foregroundStyle(HPColor.flameYellow)
                        .minimumScaleFactor(0.6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.nickname.uppercased())
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(HPColor.potatoOrange)
                        Text(context.state.exploded ? context.state.line : context.state.line)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .lineLimit(3)
                    }
                }
            } compactLeading: {
                Text("🥔")
            } compactTrailing: {
                Text(context.state.clockText)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(HPColor.flameYellow)
                    .minimumScaleFactor(0.5)
            } minimal: {
                Text(context.state.exploded ? "💥" : "🥔")
            }
        }
    }

    private func lockScreen(_ context: ActivityViewContext<PotatoLiveAttributes>) -> some View {
        HStack(spacing: 12) {
            Text(context.state.exploded ? "💥" : "🥔")
                .font(.largeTitle)
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.nickname.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(HPColor.potatoOrange)
                Text(context.state.line)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(context.state.exploded ? "COOKED" : context.state.clockText)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(HPColor.flameYellow)
            }
            Spacer()
        }
        .padding(16)
        .background(HPColor.nearBlack)
    }
}
