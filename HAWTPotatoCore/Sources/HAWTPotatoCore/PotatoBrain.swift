import Foundation

public struct DumpPick: Identifiable, Sendable, Hashable {
    public var player: PlayerRef
    public var reason: String
    public var id: String { player.id }

    public init(player: PlayerRef, reason: String) {
        self.player = player
        self.reason = reason
    }
}

/// On-device potato brain. Templates and rules only — CloudKit still decides who is cooked.
public enum PotatoBrain {
    public static func catchLine(card: HotPotatoCard, me: PlayerRef) -> String {
        let sender = card.previousHolder?.displayName ?? card.creator.displayName
        let name = firstName(me.displayName)
        let lines: [String]
        switch card.skin {
        case .classic:
            lines = [
                "\(sender) dumped this on you, \(name). It's already hot.",
                "You have it. The fuse does not care that you just sat down.",
                "Catch it, panic, throw it. That's the whole religion."
            ]
        case .classicRing:
            lines = [
                "Ring of fire, \(name). You're standing in it.",
                "Pretty flames. Mean clock. Throw.",
                "\(sender) framed you in orange. Move."
            ]
        case .day:
            lines = [
                "Looks friendly. It isn't.",
                "White heat, \(name). Still a potato. Still lethal.",
                "\(sender) sent daylight. You're still cooked if you stall."
            ]
        case .dayRing:
            lines = [
                "Halo on. Smug already. Throw before I start narrating.",
                "I would never explode. I would simply watch you explode.",
                "Blessed, glowing, and one ignored timer from shame."
            ]
        case .panic:
            lines = [
                "AAAAA \(name.uppercased()) YOU HAVE IT PASS IT PASS IT",
                "Don't think. Don't sip. THROW.",
                "\(sender) did this to you. Scream later."
            ]
        case .maniacal:
            lines = [
                "YES KEEP IT. NO THROW IT. YES. I'M HELPING.",
                "Hehe. You're holding me. That's a choice.",
                "\(sender) knows exactly what they did."
            ]
        case .shocked:
            lines = [
                "YOU CAUGHT IT? YOU CAUGHT IT.",
                "Wide eyes. Short fuse. \(name), go.",
                "\(sender) threw. Your face did the rest."
            ]
        case .distressed:
            lines = [
                "Please. Just pass me. I don't want this either.",
                "We're both stressed, \(name). Only one of us explodes.",
                "\(sender) made this your problem. Make it someone else's."
            ]
        case .wink:
            lines = [
                "Cute catch. Tragic if you keep me.",
                "Hey \(name). Dump it like you mean it.",
                "\(sender) winked this at you. That's not affection."
            ]
        case .dazed:
            lines = [
                "...oh. Hi. You're holding a potato. Probably throw that.",
                "Wait. What? Oh. Yeah. Pass it, \(name).",
                "\(sender) threw this. I forgot why. Throw anyway."
            ]
        }
        return pick(lines, salt: card.id.uuidString + "\(card.passGeneration)")
    }

    public static func holdLine(card: HotPotatoCard, me: PlayerRef, now: Date = .now) -> String {
        if card.isPaused {
            return "Paused by \(card.pausedBy?.displayName ?? "someone"). Everyone can see this."
        }
        if card.hidesClock {
            return mysteryMood(card: card, now: now)
        }
        if card.gameMode == .suddenDeath {
            return "Eight seconds. That's not a suggestion."
        }
        switch card.heat(at: now) {
        case .normal:
            return card.skin == .dayRing
                ? "I'm fine. You're the one sweating."
                : "It's warm. That's how it starts."
        case .warming:
            return "Getting loud in here. Dump it."
        case .hot:
            return card.skin == .panic ? "HOT HOT HOT THROW" : "This is the stupid part. Throw."
        case .critical:
            return "You are choosing this. Pass it."
        case .finalCountdown:
            return "NOW."
        }
    }

    public static func mysteryMood(card: HotPotatoCard, now: Date = .now) -> String {
        switch card.heat(at: now) {
        case .normal:
            return "It's humming. That's not comfort."
        case .warming:
            return "Something shifted. Don't get cute."
        case .hot:
            return "It's pacing in your hands."
        case .critical:
            return "It's whispering your name."
        case .finalCountdown:
            return "THROW. Don't look at the clock. There isn't one. THROW."
        }
    }

    public static func explodeRecap(card: HotPotatoCard) -> String {
        let loser = card.explosion?.loser.displayName ?? card.currentHolder.displayName
        let name = card.callsign
        let passes = card.passCount
        let chain = card.history
            .filter { $0.action == .received || $0.action == .claimed || $0.action == .created }
            .map(\.player.displayName)
        let path = chain.isEmpty ? loser : chain.joined(separator: " → ")
        let extra: String
        switch card.skin {
        case .panic: extra = "It was screaming the whole time."
        case .dayRing: extra = "The halo did not save anyone."
        case .wink: extra = "Winked. Then detonated."
        case .dazed: extra = "It looked confused. Then it exploded."
        case .maniacal: extra = "It wanted this."
        case .distressed: extra = "It asked nicely. Nobody listened."
        default: extra = passes == 0 ? "Nobody even threw it." : "That's the game."
        }
        if card.gameMode == .mystery {
            return "\(name) cooked \(loser). Mystery fuse was \(card.duration.hpClock). \(path). \(extra)"
        }
        return "\(name) cooked \(loser) after \(passes) pass\(passes == 1 ? "" : "es"). \(path). \(extra)"
    }

    public static func liveLine(card: HotPotatoCard, me: PlayerRef, now: Date = .now) -> String {
        if card.status == .exploded {
            return explodeRecap(card: card)
        }
        if card.isPaused {
            return "PAUSED by \(card.pausedBy?.displayName ?? "someone"). Fuse is frozen."
        }
        if card.isHeld(by: me) {
            return holdLine(card: card, me: me, now: now)
        }
        return "Currently with \(card.currentHolder.displayName)."
    }

    public static func notificationTitle(card: HotPotatoCard) -> String {
        switch card.skin {
        case .panic: return "🔥 POTATO. YOU. NOW."
        case .dayRing: return "😇 A potato arrived. Try not to embarrass us."
        case .dazed: return "🥔 wait— you have a potato"
        case .wink: return "😉 Gotcha."
        case .maniacal: return "🔥 HEHE YOU HAVE IT"
        default: return "🔥🥔 HAWT POTATO!"
        }
    }

    public static func warningCopy(card: HotPotatoCard) -> (title: String, body: String) {
        let tag = card.callsign
        if card.gameMode == .suddenDeath {
            return ("THROW OR DIE", "\(tag) · 8 seconds. That's the window.")
        }
        if card.hidesClock {
            return (mysteryMood(card: card), "\(tag) is still cooking. Pass it.")
        }
        if card.skin == .dayRing {
            return ("Still holding me?", "\(tag) · I told you this would be undignified.")
        }
        if card.skin == .panic {
            return ("🚨 PASS IT PASS IT", "\(tag) is about to blow.")
        }
        let left = card.remaining()
        if left <= 10 {
            return ("🚨 10 SECONDS — PASS IT!", "\(tag) is about to blow.")
        }
        return ("🔥 It's getting hot.", "\(tag) · \(max(0, left).hpClock) left.")
    }

    public static func hapticScale(for skin: PotatoSkin) -> Float {
        switch skin {
        case .panic: 1.25
        case .maniacal: 1.1
        case .shocked: 1.05
        case .dayRing, .wink: 0.72
        case .dazed: 0.55
        case .distressed: 0.85
        default: 1.0
        }
    }

    public static func pulseIntervalScale(for skin: PotatoSkin) -> Double {
        switch skin {
        case .panic: 0.62
        case .dazed: 1.45
        case .dayRing: 1.15
        default: 1.0
        }
    }

    public static func notificationDelay(for skin: PotatoSkin) -> TimeInterval {
        switch skin {
        case .dazed: 3.2
        case .day: 0.4
        default: 0
        }
    }

    public static func skin(forVibe raw: String) -> PotatoSkin {
        let text = raw.lowercased()
        let map: [(keys: [String], skin: PotatoSkin)] = [
            (["panic", "freak", "scream", "aaa", "chaos", "feral"], .panic),
            (["maniac", "evil", "laugh", "hehe", "villain"], .maniacal),
            (["shock", "wow", "gasp", "surprised"], .shocked),
            (["distress", "sad", "please", "help", "cry"], .distressed),
            (["wink", "flirt", "smug", "cool", "slick"], .wink),
            (["daze", "dizzy", "lost", "late", "stoned", "slow"], .dazed),
            (["halo", "angel", "holy", "bless", "smug glow"], .dayRing),
            (["ring", "fire circle", "orbit"], .classicRing),
            (["day", "white", "bright", "sun"], .day)
        ]
        for entry in map where entry.keys.contains(where: { text.contains($0) }) {
            return entry.skin
        }
        return .classic
    }

    public static func dumpPicks(
        me: PlayerRef,
        recent: [PlayerRef],
        nearby: [PlayerRef],
        potatoes: [HotPotatoCard],
        blocked: [PlayerRef]
    ) -> [DumpPick] {
        let blockedIDs = Set(blocked.map(\.id))
        var reasons: [String: DumpPick] = [:]

        for peer in nearby where peer.id != me.id && !blockedIDs.contains(peer.id) {
            reasons[peer.id] = DumpPick(player: peer, reason: "In range · dump now")
        }

        if let revenge = potatoes
            .filter({ $0.status == .exploded && $0.explosion?.loser.id == me.id })
            .compactMap(\.previousHolder)
            .last,
           revenge.id != me.id,
           !blockedIDs.contains(revenge.id) {
            reasons[revenge.id] = DumpPick(player: revenge, reason: "Cooked you last")
        }

        let fastIDs = fastDumpers(from: potatoes, besides: me.id)
        for player in recent where fastIDs.contains(player.id) && reasons[player.id] == nil && !blockedIDs.contains(player.id) {
            reasons[player.id] = DumpPick(player: player, reason: "Dumps fast")
        }

        for player in recent where player.id != me.id && reasons[player.id] == nil && !blockedIDs.contains(player.id) {
            reasons[player.id] = DumpPick(player: player, reason: "Played before")
        }

        let nearbyIDs = Set(nearby.map(\.id))
        return Array(reasons.values).sorted { lhs, rhs in
            let lNear = nearbyIDs.contains(lhs.player.id)
            let rNear = nearbyIDs.contains(rhs.player.id)
            if lNear != rNear { return lNear && !rNear }
            return lhs.reason < rhs.reason
        }
    }

    public static func repeatDumper(onto me: PlayerRef, potatoes: [HotPotatoCard], blocked: [PlayerRef]) -> PlayerRef? {
        let blockedIDs = Set(blocked.map(\.id))
        var counts: [String: (player: PlayerRef, count: Int)] = [:]
        for card in potatoes {
            for (index, event) in card.history.enumerated() where event.action == .received && event.player.id == me.id {
                let from: PlayerRef
                if index > 0 {
                    from = card.history[index - 1].player
                } else {
                    from = card.previousHolder ?? card.creator
                }
                guard from.id != me.id, !blockedIDs.contains(from.id) else { continue }
                var row = counts[from.id] ?? (from, 0)
                row.count += 1
                row.player = from
                counts[from.id] = row
            }
        }
        return counts.values.filter { $0.count >= 4 }.max(by: { $0.count < $1.count })?.player
    }

    public static func weeklyStory(me: PlayerRef, potatoes: [HotPotatoCard], now: Date = .now) -> String {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let week = potatoes.filter { card in
            (card.explosion?.explodedAt ?? card.createdAt) >= start
        }
        let cooked = week.filter { $0.status == .exploded }
        let myCooks = cooked.filter { $0.explosion?.loser.id == me.id }.count
        let myDumps = week.filter { card in
            card.history.contains { $0.action == .passed && $0.player.id == me.id }
        }.count
        let shame = Dictionary(grouping: cooked.compactMap(\.explosion?.loser), by: \.id)
            .max { $0.value.count < $1.value.count }?.value.first
        if cooked.isEmpty {
            return "This week: nobody got cooked. That's suspicious. Light one."
        }
        var parts = ["This week: \(cooked.count) potato\(cooked.count == 1 ? "" : "es") exploded."]
        if let shame {
            parts.append("\(shame.displayName) led the shame board.")
        }
        if myCooks > 0 {
            parts.append("You got cooked \(myCooks)×.")
        } else {
            parts.append("You didn't get cooked. Yet.")
        }
        parts.append("You dumped \(myDumps).")
        return parts.joined(separator: " ")
    }

    public static func groupThrowWarning() -> String {
        "First catch in the iMessage chat wins. Long-press a potato to throw it fast."
    }

    public static func hottestQueueHint(holdingCount: Int) -> String? {
        guard holdingCount > 1 else { return nil }
        return "Hottest one is on top. That fuse cooks you first."
    }

    private static func fastDumpers(from potatoes: [HotPotatoCard], besides meID: String) -> Set<String> {
        var best: [String: TimeInterval] = [:]
        for card in potatoes {
            for (index, event) in card.history.enumerated() where event.action == .passed && event.player.id != meID {
                let received = card.history.prefix(index).last { $0.player.id == event.player.id && ($0.action == .received || $0.action == .created || $0.action == .claimed) }
                guard let received else { continue }
                let hold = event.at.timeIntervalSince(received.at)
                if hold > 0, hold < (best[event.player.id] ?? .greatestFiniteMagnitude) {
                    best[event.player.id] = hold
                }
            }
        }
        return Set(best.filter { $0.value <= 12 }.map(\.key))
    }

    private static func firstName(_ name: String) -> String {
        String(name.split(separator: " ").first ?? Substring(name))
    }

    private static func pick(_ lines: [String], salt: String) -> String {
        guard !lines.isEmpty else { return "Pass it." }
        let index = abs(salt.hashValue) % lines.count
        return lines[index]
    }
}
