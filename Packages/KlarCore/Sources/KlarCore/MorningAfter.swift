import Foundation

/// „Wie geht's dir heute körperlich?" — gut / angeschlagen / verkatert.
public enum MorningBody: String, Codable, CaseIterable, Sendable {
    case fine, rough, hungover
}

/// „Bereust du etwas von gestern?" — nein / ein bisschen / ja.
///
/// The middle case is `slightly`, not `some`: the value is always optional, and `.some` would
/// resolve to `Optional.some`.
public enum MorningRegret: String, Codable, CaseIterable, Sendable {
    case no, slightly, yes
}

/// „Würdest du es wieder so machen?" — ja / anders / nein.
public enum MorningAgain: String, Codable, CaseIterable, Sendable {
    case yes, differently, no
}

/// One logical day's morning-after answers (concept v3, module C).
///
/// A record with no answers is a skip. It exists so the day is never asked about again.
public struct MorningAfterDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var dayKey: String
    public var body: MorningBody?
    public var regret: MorningRegret?
    public var again: MorningAgain?
    public var note: String?
    /// Problem solving: „Was war der Auslöser?"
    public var trigger: String?
    /// „Was hätte geholfen?"
    public var wouldHaveHelped: String?
    /// „Was machst du nächstes Mal anders?" — the one answer shown back with the pattern.
    public var nextTime: String?
    public var recordedAt: Date

    public var isAnswered: Bool { body != nil || regret != nil || again != nil }

    public init(
        id: UUID = UUID(),
        dayKey: String,
        body: MorningBody? = nil,
        regret: MorningRegret? = nil,
        again: MorningAgain? = nil,
        note: String? = nil,
        trigger: String? = nil,
        wouldHaveHelped: String? = nil,
        nextTime: String? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.dayKey = dayKey
        self.body = body
        self.regret = regret
        self.again = again
        self.note = note
        self.trigger = trigger
        self.wouldHaveHelped = wouldHaveHelped
        self.nextTime = nextTime
        self.recordedAt = recordedAt
    }
}
