public enum SubstanceUnit: String, Codable, CaseIterable, Sendable {
    case mg, g, ml, piece, drink
}

public enum GoalType: String, Codable, CaseIterable, Sendable {
    case reduction, abstinence, observe
}

public enum PlanStatus: String, Codable, CaseIterable, Sendable {
    case active, paused, archived
}

public enum CheckInOutcome: String, Codable, CaseIterable, Sendable {
    case helped, notHelped, adjusted
}

public enum ReviewPlanDecision: String, Codable, CaseIterable, Sendable {
    case keep, adjust, pause
}
