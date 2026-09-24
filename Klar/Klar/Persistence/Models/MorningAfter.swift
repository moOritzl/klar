import Foundation
import SwiftData
import KlarCore

/// One logical day's „Der Morgen danach" answers. A record with no answers is a skip.
@Model
final class MorningAfter {
    var id: UUID = UUID()
    var dayKey: String = ""
    var bodyRawValue: String?
    var regretRawValue: String?
    var againRawValue: String?
    var note: String?
    var trigger: String?
    var wouldHaveHelped: String?
    var nextTime: String?
    var recordedAt: Date = Date()

    var body: MorningBody? {
        get { bodyRawValue.flatMap(MorningBody.init(rawValue:)) }
        set { bodyRawValue = newValue?.rawValue }
    }

    var regret: MorningRegret? {
        get { regretRawValue.flatMap(MorningRegret.init(rawValue:)) }
        set { regretRawValue = newValue?.rawValue }
    }

    var again: MorningAgain? {
        get { againRawValue.flatMap(MorningAgain.init(rawValue:)) }
        set { againRawValue = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        dayKey: String,
        body: MorningBody? = nil,
        regret: MorningRegret? = nil,
        again: MorningAgain? = nil,
        note: String? = nil,
        trigger: String? = nil,
        wouldHaveHelped: String? = nil,
        nextTime: String? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.dayKey = dayKey
        self.bodyRawValue = body?.rawValue
        self.regretRawValue = regret?.rawValue
        self.againRawValue = again?.rawValue
        self.note = note
        self.trigger = trigger
        self.wouldHaveHelped = wouldHaveHelped
        self.nextTime = nextTime
        self.recordedAt = recordedAt
    }
}
