import Foundation
import SwiftData

@Model
final class ContextTag {
    var id: UUID = UUID()
    var name: String = ""
    var isBuiltIn: Bool = false

    init(id: UUID = UUID(), name: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
    }
}
