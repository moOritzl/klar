import Foundation
import SwiftData

@Model
final class ContextTag {
    var id: UUID = UUID()
    var name: String = ""
    var isBuiltIn: Bool = false

    /// Declared only to make the relationship many-to-many. Without an explicit
    /// inverse, SwiftData infers a to-one on this side, so assigning a tag to a
    /// second entry silently takes it off the first.
    @Relationship(inverse: \Entry.contextTags) var entries: [Entry]?

    init(id: UUID = UUID(), name: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
    }
}
