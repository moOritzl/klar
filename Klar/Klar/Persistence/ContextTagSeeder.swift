import Foundation
import SwiftData

enum ContextTagSeeder {
    static let builtInNames = ["Allein", "Sozial", "Club", "Zuhause"]

    static func seedIfNeeded(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<ContextTag>())
        let existingBuiltInNames = Set(existing.filter(\.isBuiltIn).map(\.name))
        for name in builtInNames where !existingBuiltInNames.contains(name) {
            context.insert(ContextTag(name: name, isBuiltIn: true))
        }
        if context.hasChanges {
            try context.save()
        }
    }
}
