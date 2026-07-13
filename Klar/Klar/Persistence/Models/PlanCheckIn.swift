import Foundation
import SwiftData
import KlarCore

@Model
final class PlanCheckIn {
    var id: UUID = UUID()
    var plan: Plan?
    var entry: Entry?
    var date: Date = Date()
    var outcomeRawValue: String = CheckInOutcome.helped.rawValue

    var outcome: CheckInOutcome {
        get { CheckInOutcome(rawValue: outcomeRawValue) ?? .helped }
        set { outcomeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        plan: Plan?,
        entry: Entry?,
        date: Date,
        outcome: CheckInOutcome
    ) {
        self.id = id
        self.plan = plan
        self.entry = entry
        self.date = date
        self.outcomeRawValue = outcome.rawValue
    }
}
