import Foundation

public struct SubstanceDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var unit: SubstanceUnit
    public var colorIndex: Int
    public var costPerUnitRaw: String?
    public var sortOrder: Int
    public var isArchived: Bool
    public var asksMorningAfter: Bool

    public var costPerUnit: Decimal? {
        get { costPerUnitRaw.flatMap { Decimal(string: $0) } }
        set { costPerUnitRaw = newValue.map { "\($0)" } }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        unit: SubstanceUnit,
        colorIndex: Int,
        costPerUnit: Decimal? = nil,
        sortOrder: Int,
        isArchived: Bool = false,
        asksMorningAfter: Bool = true
    ) {
        self.id = id
        self.name = name
        self.unit = unit
        self.colorIndex = colorIndex
        self.costPerUnitRaw = costPerUnit.map { "\($0)" }
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.asksMorningAfter = asksMorningAfter
    }
}

public struct EntryDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var substanceID: UUID?
    public var timestamp: Date
    public var timezoneID: String
    public var amountRaw: String?
    public var unitOverride: String?
    public var contextTagIDs: [UUID]?
    public var mood: Int?
    public var note: String?
    public var createdAt: Date
    public var editedAt: Date?

    public var amount: Decimal? {
        get { amountRaw.flatMap { Decimal(string: $0) } }
        set { amountRaw = newValue.map { "\($0)" } }
    }

    public init(
        id: UUID = UUID(),
        substanceID: UUID?,
        timestamp: Date,
        timezoneID: String,
        amount: Decimal?,
        unitOverride: String? = nil,
        contextTagIDs: [UUID]? = nil,
        mood: Int? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        editedAt: Date? = nil
    ) {
        self.id = id
        self.substanceID = substanceID
        self.timestamp = timestamp
        self.timezoneID = timezoneID
        self.amountRaw = amount.map { "\($0)" }
        self.unitOverride = unitOverride
        self.contextTagIDs = contextTagIDs
        self.mood = mood
        self.note = note
        self.createdAt = createdAt
        self.editedAt = editedAt
    }
}

public struct ContextTagDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var isBuiltIn: Bool

    public init(id: UUID = UUID(), name: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
    }
}

public struct GoalPeriodDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var substanceID: UUID?
    public var type: GoalType
    public var monthlyLimit: Int?
    public var validFrom: Date
    public var validUntil: Date?

    public init(
        id: UUID = UUID(),
        substanceID: UUID?,
        type: GoalType,
        monthlyLimit: Int? = nil,
        validFrom: Date,
        validUntil: Date? = nil
    ) {
        self.id = id
        self.substanceID = substanceID
        self.type = type
        self.monthlyLimit = monthlyLimit
        self.validFrom = validFrom
        self.validUntil = validUntil
    }
}

public struct SubstitutionActionDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var text: String
    public var sortOrder: Int

    public init(id: UUID = UUID(), text: String, sortOrder: Int) {
        self.id = id
        self.text = text
        self.sortOrder = sortOrder
    }
}

public struct WhyNoteDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var text: String
    public var createdAt: Date

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

public struct KlarExport: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var exportedAt: Date
    public var substances: [SubstanceDTO]
    public var entries: [EntryDTO]
    public var contextTags: [ContextTagDTO]
    public var goalPeriods: [GoalPeriodDTO]
    public var substitutionActions: [SubstitutionActionDTO]
    public var whyNotes: [WhyNoteDTO]
    public var morningAfters: [MorningAfterDTO]

    public init(
        schemaVersion: Int = KlarExport.currentSchemaVersion,
        exportedAt: Date = Date(),
        substances: [SubstanceDTO] = [],
        entries: [EntryDTO] = [],
        contextTags: [ContextTagDTO] = [],
        goalPeriods: [GoalPeriodDTO] = [],
        substitutionActions: [SubstitutionActionDTO] = [],
        whyNotes: [WhyNoteDTO] = [],
        morningAfters: [MorningAfterDTO] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.substances = substances
        self.entries = entries
        self.contextTags = contextTags
        self.goalPeriods = goalPeriods
        self.substitutionActions = substitutionActions
        self.whyNotes = whyNotes
        self.morningAfters = morningAfters
    }
}

public enum KlarExportCoding {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
