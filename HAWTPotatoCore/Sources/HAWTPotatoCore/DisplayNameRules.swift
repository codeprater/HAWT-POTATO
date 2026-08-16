import Foundation

public enum DisplayNameRules {
    public static func sanitized(_ raw: String, limit: Int = 24) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Player" }
        let folded = normalize(trimmed)
        if banned.contains(where: { folded.contains($0) }) {
            return "Player"
        }
        return String(trimmed.prefix(limit))
    }

    public static func sanitizedNickname(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let name = sanitized(trimmed, limit: 16)
        return name == "Player" ? nil : name
    }

    public static func sanitizedNote(_ raw: String, limit: Int = 20) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let folded = normalize(trimmed)
        if banned.contains(where: { folded.contains($0) }) { return nil }
        return String(trimmed.prefix(limit))
    }

    private static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let mapped = lowered.map { leet[$0] ?? $0 }
        return String(mapped).replacingOccurrences(of: " ", with: "")
    }

    private static let leet: [Character: Character] = [
        "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s"
    ]

    private static let banned = [
        "fuck", "shit", "nigger", "nigga", "faggot", "cunt", "rape", "porn", "pedo",
        "kike", "retard", "slut", "whore", "nazi", "hitler", "killyourself", "kys"
    ]
}
