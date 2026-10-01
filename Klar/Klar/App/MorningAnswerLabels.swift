import KlarCore

// The words each answer is shown with — on the card, in the Muster tab and in the day detail.
// Kept in one place so a label can never read differently in two spots.

extension MorningBody {
    var label: String {
        switch self {
        case .fine: "gut"
        case .rough: "angeschlagen"
        case .hungover: "verkatert"
        }
    }
}

extension MorningRegret {
    var label: String {
        switch self {
        case .no: "nein"
        case .slightly: "ein bisschen"
        case .yes: "ja"
        }
    }
}

extension MorningAgain {
    var label: String {
        switch self {
        case .yes: "ja"
        case .differently: "anders"
        case .no: "nein"
        }
    }
}
