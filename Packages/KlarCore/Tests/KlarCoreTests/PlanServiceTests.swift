import XCTest
@testable import KlarCore

final class PlanServiceTests: XCTestCase {
    private let tz = "Europe/Berlin"

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: tz)!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testVersioningChainIntactAfterTwoEdits() throws {
        let (nilOld1, v1) = try PlanService.createVersion(
            of: nil, situationTagID: nil, situationText: "Stress", actionText: "Spazieren gehen",
            existingPlans: [], now: date(2026, 1, 1, 10, 0)
        )
        XCTAssertNil(nilOld1)

        let (updatedV1, v2) = try PlanService.createVersion(
            of: v1, situationTagID: nil, situationText: "Stress", actionText: "Anrufen statt trinken",
            existingPlans: [v1], now: date(2026, 2, 1, 10, 0)
        )
        let archivedV1 = try XCTUnwrap(updatedV1)
        XCTAssertEqual(archivedV1.status, .archived)
        XCTAssertEqual(archivedV1.supersededBy, v2.id)
        XCTAssertEqual(v2.status, .active)
        XCTAssertNil(v2.supersededBy)

        let (updatedV2, v3) = try PlanService.createVersion(
            of: v2, situationTagID: nil, situationText: "Stress", actionText: "Atemübung",
            existingPlans: [archivedV1, v2], now: date(2026, 3, 1, 10, 0)
        )
        let archivedV2 = try XCTUnwrap(updatedV2)
        XCTAssertEqual(archivedV2.status, .archived)
        XCTAssertEqual(archivedV2.supersededBy, v3.id)
        XCTAssertEqual(v3.status, .active)

        // full chain still traceable
        XCTAssertEqual(archivedV1.supersededBy, archivedV2.id)
        XCTAssertEqual(archivedV2.supersededBy, v3.id)
    }

    func testActivePlanLimitEnforced() throws {
        var existingPlans: [PlanDTO] = []
        for i in 0..<3 {
            let (_, plan) = try PlanService.createVersion(
                of: nil, situationTagID: nil, situationText: "Situation \(i)", actionText: "Action \(i)",
                existingPlans: existingPlans, now: date(2026, 1, 1, 10, 0)
            )
            existingPlans.append(plan)
        }
        XCTAssertEqual(existingPlans.filter { $0.status == .active }.count, 3)

        XCTAssertThrowsError(try PlanService.createVersion(
            of: nil, situationTagID: nil, situationText: "One too many", actionText: "Nope",
            existingPlans: existingPlans, now: date(2026, 1, 1, 10, 0)
        )) { error in
            XCTAssertEqual(error as? PlanServiceError, .activePlanLimitReached)
        }

        // editing one of the 3 (replacing, not adding) must still succeed at the limit
        let editing = existingPlans[0]
        XCTAssertNoThrow(try PlanService.createVersion(
            of: editing, situationTagID: nil, situationText: "Edited", actionText: "Edited action",
            existingPlans: existingPlans, now: date(2026, 1, 1, 10, 0)
        ))
    }

    func testCheckInDueNotDueMatrix() {
        let tagID = UUID()
        let activePlan = PlanDTO(situationTagID: tagID, situationText: "Sozial", actionText: "Wasser bestellen",
                                  committedAt: date(2026, 1, 1, 10, 0), status: .active)
        let pausedPlan = PlanDTO(situationTagID: tagID, situationText: "Sozial", actionText: "Wasser bestellen",
                                  committedAt: date(2026, 1, 1, 10, 0), status: .paused)

        let earlierDayEntry = EntryDTO(substanceID: UUID(), timestamp: date(2026, 1, 5, 20, 0), timezoneID: tz,
                                        amount: 1, contextTagIDs: [tagID])
        let sameDayAsNowEntry = EntryDTO(substanceID: UUID(), timestamp: date(2026, 1, 10, 20, 0), timezoneID: tz,
                                          amount: 1, contextTagIDs: [tagID])
        let unrelatedTagEntry = EntryDTO(substanceID: UUID(), timestamp: date(2026, 1, 5, 20, 0), timezoneID: tz,
                                          amount: 1, contextTagIDs: [UUID()])
        let now = date(2026, 1, 10, 9, 0)

        // Case 1: earlier logical day, active plan, no check-in yet -> due
        let due = PlanService.pendingCheckIns(
            entries: [earlierDayEntry], plans: [activePlan], existingCheckIns: [],
            now: now, nowTimezoneID: tz
        )
        XCTAssertEqual(due.count, 1)
        XCTAssertEqual(due.first?.entry.id, earlierDayEntry.id)

        // Case 2: entry on the same logical day as "now" -> not due
        let sameDayResult = PlanService.pendingCheckIns(
            entries: [sameDayAsNowEntry], plans: [activePlan], existingCheckIns: [],
            now: now, nowTimezoneID: tz
        )
        XCTAssertTrue(sameDayResult.isEmpty)

        // Case 3: already checked in -> not due
        let existingCheckIn = PlanCheckInDTO(planID: activePlan.id, entryID: earlierDayEntry.id,
                                              date: date(2026, 1, 6, 10, 0), outcome: .helped)
        let alreadyCheckedIn = PlanService.pendingCheckIns(
            entries: [earlierDayEntry], plans: [activePlan], existingCheckIns: [existingCheckIn],
            now: now, nowTimezoneID: tz
        )
        XCTAssertTrue(alreadyCheckedIn.isEmpty)

        // Case 4: entry's tags don't match the plan's situation tag -> not due
        let unrelated = PlanService.pendingCheckIns(
            entries: [unrelatedTagEntry], plans: [activePlan], existingCheckIns: [],
            now: now, nowTimezoneID: tz
        )
        XCTAssertTrue(unrelated.isEmpty)

        // Case 5: plan not active -> not due
        let pausedResult = PlanService.pendingCheckIns(
            entries: [earlierDayEntry], plans: [pausedPlan], existingCheckIns: [],
            now: now, nowTimezoneID: tz
        )
        XCTAssertTrue(pausedResult.isEmpty)
    }
}
