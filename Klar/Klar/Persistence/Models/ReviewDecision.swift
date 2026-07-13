import Foundation
import SwiftData
import KlarCore

@Model
final class ReviewDecision {
    var id: UUID = UUID()
    var weekStart: Date = Date()
    var planDecisionRawValue: String = ReviewPlanDecision.keep.rawValue

    var planDecision: ReviewPlanDecision {
        get { ReviewPlanDecision(rawValue: planDecisionRawValue) ?? .keep }
        set { planDecisionRawValue = newValue.rawValue }
    }

    init(id: UUID = UUID(), weekStart: Date, planDecision: ReviewPlanDecision) {
        self.id = id
        self.weekStart = weekStart
        self.planDecisionRawValue = planDecision.rawValue
    }
}
