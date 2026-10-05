import Foundation
import KlarCore

/// How a morning-after pattern reads, everywhere it appears. Counts in a fixed order, zeros
/// left out, no adjective and no verdict (P7).
enum MorningPatternText {
    /// "letzte 5: 3× verkatert, 1× bereut" — Übersicht and the entry sheet, newest five days.
    static func summary(_ pattern: MorningPattern) -> String {
        "letzte \(pattern.days): \(fragments(pattern))"
    }

    /// "5 Tage: 4× verkatert, 1× bereut" — the Muster tab, which counts every answered day.
    static func tally(_ pattern: MorningPattern) -> String {
        "\(pattern.days) Tage: \(fragments(pattern))"
    }

    /// "Davon 3 Tage zusammen mit Cannabis, 1 mit Alkohol". A day's answers belong to every
    /// substance of that day, so the evaluation says which days were shared.
    static func sharedDaysText(_ shared: [(name: String, days: Int)]) -> String {
        guard let first = shared.first else { return "" }
        let head = "Davon \(first.days) \(first.days == 1 ? "Tag" : "Tage") zusammen mit \(first.name)"
        let rest = shared.dropFirst().map { "\($0.days) mit \($0.name)" }
        return ([head] + rest).joined(separator: ", ")
    }

    /// The problem-solving answers of one day, each labelled, empty ones left out.
    static func reflectionLines(trigger: String?, wouldHaveHelped: String?, nextTime: String?) -> [String] {
        [("Auslöser", trigger), ("Hätte geholfen", wouldHaveHelped), ("Nächstes Mal", nextTime)]
            .compactMap { label, text in
                guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
                return "\(label): \(text)"
            }
    }

    /// "Körper: verkatert" — one line per answered question, for the day detail.
    static func answerLines(body: MorningBody?, regret: MorningRegret?, again: MorningAgain?) -> [String] {
        var lines: [String] = []
        if let body { lines.append("Körper: \(body.label)") }
        if let regret { lines.append("Reue: \(regret.label)") }
        if let again { lines.append("Nochmal so: \(again.label)") }
        return lines
    }

    /// Whether a day's record holds anything to show: an answer, a note, or reflection text.
    /// A record without any of it is a skipped day. (Patterns still count answers only.)
    static func hasContent(
        body: MorningBody?, regret: MorningRegret?, again: MorningAgain?,
        note: String?, trigger: String?, wouldHaveHelped: String?, nextTime: String?
    ) -> Bool {
        if body != nil || regret != nil || again != nil { return true }
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return !reflectionLines(trigger: trigger, wouldHaveHelped: wouldHaveHelped, nextTime: nextTime).isEmpty
    }

    private static func fragments(_ pattern: MorningPattern) -> String {
        var parts: [String] = []
        if let count = pattern.body[.hungover], count > 0 { parts.append("\(count)× verkatert") }
        if let count = pattern.body[.rough], count > 0 { parts.append("\(count)× angeschlagen") }
        if let count = pattern.regret[.yes], count > 0 { parts.append("\(count)× bereut") }
        if let count = pattern.regret[.slightly], count > 0 { parts.append("\(count)× ein bisschen bereut") }

        if !parts.isEmpty { return parts.joined(separator: ", ") }
        if pattern.body.isEmpty && pattern.regret.isEmpty { return "ohne Angaben zu Kater und Reue" }
        return "kein Kater, nichts bereut"
    }

    /// "Mit Club · letzte 4: 3× verkatert"
    static func contextual(_ pattern: MorningPattern, tagName: String) -> String {
        "Mit \(tagName) · \(summary(pattern))"
    }
}
