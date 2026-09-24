public enum SubstanceUnit: String, Codable, CaseIterable, Sendable {
    case mg, g, ml, piece, drink
}

public enum GoalType: String, Codable, CaseIterable, Sendable {
    case reduction, abstinence, observe
}
