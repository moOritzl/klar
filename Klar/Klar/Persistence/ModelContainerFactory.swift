import Foundation
import SwiftData

enum ModelContainerFactory {
    static let storeFileName = "Klar.sqlite"

    static let schema = Schema([
        Substance.self,
        Entry.self,
        ContextTag.self,
        GoalPeriod.self,
        Plan.self,
        PlanCheckIn.self,
        SubstitutionAction.self,
        WhyNote.self,
        ReviewDecision.self
    ])

    static func makeContainer(fileManager: FileManager = .default) -> ModelContainer {
        let directory = AppGroupContainer.storeDirectory(fileManager: fileManager)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        BackupExclusion.apply(to: directory)

        let storeURL = directory.appendingPathComponent(storeFileName)
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
