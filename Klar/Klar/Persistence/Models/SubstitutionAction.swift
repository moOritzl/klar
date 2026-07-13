import Foundation
import SwiftData

@Model
final class SubstitutionAction {
    var id: UUID = UUID()
    var text: String = ""
    var sortOrder: Int = 0

    init(id: UUID = UUID(), text: String, sortOrder: Int) {
        self.id = id
        self.text = text
        self.sortOrder = sortOrder
    }
}
