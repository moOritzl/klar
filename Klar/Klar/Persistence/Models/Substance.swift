import Foundation
import SwiftData
import KlarCore

@Model
final class Substance {
    var id: UUID = UUID()
    var name: String = ""
    var unitRawValue: String = SubstanceUnit.mg.rawValue
    var colorIndex: Int = 0
    var costPerUnitRaw: String?
    var sortOrder: Int = 0
    var isArchived: Bool = false

    var unit: SubstanceUnit {
        get { SubstanceUnit(rawValue: unitRawValue) ?? .mg }
        set { unitRawValue = newValue.rawValue }
    }

    var costPerUnit: Decimal? {
        get { costPerUnitRaw.flatMap { Decimal(string: $0) } }
        set { costPerUnitRaw = newValue.map { "\($0)" } }
    }

    init(
        id: UUID = UUID(),
        name: String,
        unit: SubstanceUnit,
        colorIndex: Int,
        costPerUnit: Decimal? = nil,
        sortOrder: Int,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.unitRawValue = unit.rawValue
        self.colorIndex = colorIndex
        self.costPerUnitRaw = costPerUnit.map { "\($0)" }
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
}
