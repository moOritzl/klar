import Foundation

/// How a monthly limit is read out, everywhere it appears.
///
/// The numeral is the month's real count and keeps counting past the limit: „1 von max. 3",
/// „2 von max. 2", „4 von max. 2". It used to show what was *left* and switch to what was used
/// once nothing was left („Noch 1 von 2" → „2 von 2"), so the same position on the card meant
/// two different things — and past the limit „what is left" is always 0, which hides the one
/// number anyone opens the card for. Counting up needs no second line and no special case.
public struct QuotaReading: Sendable, Equatable {
    public let limit: Int
    /// Occasions this month.
    public let count: Int

    public init(limit: Int, remaining: Int) {
        self.limit = limit
        self.count = max(limit - remaining, 0)
    }

    /// The whole reading as one line — the card splits it for weighting, VoiceOver uses it as is.
    public var text: String { "\(count) von max. \(limit)" }
}
