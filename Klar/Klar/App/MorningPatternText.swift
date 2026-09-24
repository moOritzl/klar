import Foundation
import KlarCore

/// How a morning-after pattern reads, everywhere it appears. Counts in a fixed order, zeros
/// left out, no adjective and no verdict (P7).
enum MorningPatternText {
    /// "letzte 5: 3× verkatert, 1× bereut"
    static func summary(_ pattern: MorningPattern) -> String {
        var parts: [String] = []
        if let count = pattern.body[.hungover], count > 0 { parts.append("\(count)× verkatert") }
        if let count = pattern.body[.rough], count > 0 { parts.append("\(count)× angeschlagen") }
        if let count = pattern.regret[.yes], count > 0 { parts.append("\(count)× bereut") }
        if let count = pattern.regret[.slightly], count > 0 { parts.append("\(count)× ein bisschen bereut") }

        let tail: String
        if !parts.isEmpty {
            tail = parts.joined(separator: ", ")
        } else if pattern.body.isEmpty && pattern.regret.isEmpty {
            tail = "ohne Angaben zu Kater und Reue"
        } else {
            tail = "kein Kater, nichts bereut"
        }
        return "letzte \(pattern.days): \(tail)"
    }

    /// "Mit Club · letzte 4: 3× verkatert"
    static func contextual(_ pattern: MorningPattern, tagName: String) -> String {
        "Mit \(tagName) · \(summary(pattern))"
    }
}
