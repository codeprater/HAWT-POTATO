#if os(iOS)
import ActivityKit
import Foundation

public struct PotatoLiveAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var holderName: String
        public var clockText: String
        public var line: String
        public var nickname: String
        public var heat: String
        public var exploded: Bool

        public init(
            holderName: String,
            clockText: String,
            line: String,
            nickname: String,
            heat: String,
            exploded: Bool
        ) {
            self.holderName = holderName
            self.clockText = clockText
            self.line = line
            self.nickname = nickname
            self.heat = heat
            self.exploded = exploded
        }
    }

    public var potatoID: String
    public var shortCode: String

    public init(potatoID: String, shortCode: String) {
        self.potatoID = potatoID
        self.shortCode = shortCode
    }

    public static func state(for card: HotPotatoCard, me: PlayerRef, now: Date = .now) -> ContentState {
        ContentState(
            holderName: card.currentHolder.displayName,
            clockText: card.clockText(at: now, isHolder: card.isHeld(by: me)),
            line: PotatoBrain.liveLine(card: card, me: me, now: now),
            nickname: card.callsign,
            heat: card.heat(at: now).rawValue,
            exploded: card.status == .exploded
        )
    }
}
#endif
