import Foundation
import SwiftData
import KlarCore

@Model
final class Plan {
    var id: UUID = UUID()
    var situationTag: ContextTag?
    var situationText: String = ""
    var actionText: String = ""
    var committedAt: Date = Date()
    var statusRawValue: String = PlanStatus.active.rawValue
    var supersededBy: UUID?

    var status: PlanStatus {
        get { PlanStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        situationTag: ContextTag?,
        situationText: String,
        actionText: String,
        committedAt: Date = Date(),
        status: PlanStatus = .active,
        supersededBy: UUID? = nil
    ) {
        self.id = id
        self.situationTag = situationTag
        self.situationText = situationText
        self.actionText = actionText
        self.committedAt = committedAt
        self.statusRawValue = status.rawValue
        self.supersededBy = supersededBy
    }
}
