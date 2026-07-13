import Foundation
import SwiftData

@Model
final class WhyNote {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}
