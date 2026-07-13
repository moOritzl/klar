import Foundation
import SwiftData

@Model
final class Entry {
    var id: UUID = UUID()
    var substance: Substance?
    var timestamp: Date = Date()
    var timezoneID: String = TimeZone.current.identifier
    var amountRaw: String?
    var unitOverride: String?
    var contextTags: [ContextTag]?
    var mood: Int?
    var note: String?
    var createdAt: Date = Date()
    var editedAt: Date?

    var amount: Decimal? {
        get { amountRaw.flatMap { Decimal(string: $0) } }
        set { amountRaw = newValue.map { "\($0)" } }
    }

    init(
        id: UUID = UUID(),
        substance: Substance?,
        timestamp: Date,
        timezoneID: String,
        amount: Decimal?,
        unitOverride: String? = nil,
        contextTags: [ContextTag]? = nil,
        mood: Int? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        editedAt: Date? = nil
    ) {
        self.id = id
        self.substance = substance
        self.timestamp = timestamp
        self.timezoneID = timezoneID
        self.amountRaw = amount.map { "\($0)" }
        self.unitOverride = unitOverride
        self.contextTags = contextTags
        self.mood = mood
        self.note = note
        self.createdAt = createdAt
        self.editedAt = editedAt
    }
}
