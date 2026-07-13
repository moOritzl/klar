import Foundation
import SwiftData
import KlarCore

@Model
final class GoalPeriod {
    var id: UUID = UUID()
    var substance: Substance?
    var typeRawValue: String = GoalType.reduction.rawValue
    var monthlyLimit: Int?
    var validFrom: Date = Date()
    var validUntil: Date?

    var type: GoalType {
        get { GoalType(rawValue: typeRawValue) ?? .reduction }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        substance: Substance?,
        type: GoalType,
        monthlyLimit: Int? = nil,
        validFrom: Date,
        validUntil: Date? = nil
    ) {
        self.id = id
        self.substance = substance
        self.typeRawValue = type.rawValue
        self.monthlyLimit = monthlyLimit
        self.validFrom = validFrom
        self.validUntil = validUntil
    }
}
