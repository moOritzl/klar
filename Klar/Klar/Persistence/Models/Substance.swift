import Foundation
import SwiftData
import KlarCore

@Model
final class Substance {
    var id: UUID = UUID()
    var name: String = ""
    var unitRawValue: String = SubstanceUnit.mg.rawValue
    var colorIndex: Int = 0
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var asksMorningAfter: Bool = true

    var unit: SubstanceUnit {
        get { SubstanceUnit(rawValue: unitRawValue) ?? .mg }
        set { unitRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        unit: SubstanceUnit,
        colorIndex: Int,
        sortOrder: Int,
        isArchived: Bool = false,
        asksMorningAfter: Bool = true
    ) {
        self.id = id
        self.name = name
        self.unitRawValue = unit.rawValue
        self.colorIndex = colorIndex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.asksMorningAfter = asksMorningAfter
    }
}
