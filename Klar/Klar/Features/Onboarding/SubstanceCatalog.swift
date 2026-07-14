import Foundation
import KlarCore

/// The starter list offered in onboarding (A2). Alphabetical, no icons, no risk ordering —
/// "ohne Wertung". The order here *is* the order on screen.
struct SubstanceTemplate: Identifiable, Hashable {
    let name: String
    let unit: SubstanceUnit

    var id: String { name }
}

enum SubstanceCatalog {
    static let starters: [SubstanceTemplate] = [
        SubstanceTemplate(name: "Alkohol", unit: .drink),
        SubstanceTemplate(name: "Amphetamin", unit: .mg),
        SubstanceTemplate(name: "Cannabis", unit: .g),
        SubstanceTemplate(name: "Ketamin", unit: .mg),
        SubstanceTemplate(name: "Kokain", unit: .mg),
        SubstanceTemplate(name: "MDMA", unit: .mg),
        SubstanceTemplate(name: "Nikotin", unit: .piece)
    ]
}
