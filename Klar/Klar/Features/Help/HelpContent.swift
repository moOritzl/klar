import Foundation

// MARK: - Beratung (H4)

/// A counseling offer. `phone` is dialled directly; `url` opens a directory or website.
struct CounselingOffer: Identifiable {
    let name: String
    let phone: String?
    let url: URL?
    let badges: [Badge]
    let note: String?

    var id: String { name }

    enum Badge: Hashable {
        case anonymous, free, roundTheClock, custom(String)

        var label: String {
            switch self {
            case .anonymous: "Anonym"
            case .free: "Kostenlos"
            case .roundTheClock: "24/7"
            case .custom(let text): text
            }
        }

        /// Anonymity and cost are the two things that decide whether someone actually calls,
        /// so they get the emphasized treatment.
        var isEmphasized: Bool {
            switch self {
            case .anonymous, .free: true
            default: false
            }
        }
    }
}

enum CounselingDirectory {
    /// Nationwide German services only.
    ///
    /// These are real, publicly listed numbers. The draft (H4) also shows city-level entries with
    /// distances — that requires a vetted, maintained directory, which this app does not ship.
    /// Rather than invent local services, the city section links out to the DHS's official
    /// directory. Inventing a counseling contact in an app like this could send someone to a
    /// number that doesn't answer, at the worst possible moment.
    static let national: [CounselingOffer] = [
        CounselingOffer(
            name: "Sucht & Drogen Hotline",
            phone: "018063130 31",
            url: nil,
            badges: [.anonymous, .roundTheClock, .custom("0,20 €/Anruf")],
            note: "Bundesweite Beratung rund um die Uhr."
        ),
        CounselingOffer(
            name: "BZgA-Infotelefon zur Suchtvorbeugung",
            phone: "022189 2031",
            url: URL(string: "https://www.drugcom.de"),
            badges: [.anonymous, .free],
            note: "Mo–Do 10–22 Uhr, Fr–So 10–18 Uhr."
        ),
        CounselingOffer(
            name: "TelefonSeelsorge",
            phone: "08001110 111",
            url: URL(string: "https://www.telefonseelsorge.de"),
            badges: [.anonymous, .free, .roundTheClock],
            note: "Für alles, was gerade zu viel ist."
        )
    ]

    /// The official, maintained directory of local Suchtberatungsstellen.
    static let localDirectoryURL = URL(string: "https://www.dhs.de/service/suchthilfeverzeichnis")!
}

// MARK: - Risiko-Infos (H5)

/// Harm-avoidance information only: what can go wrong, what must not be combined, when to call
/// 112. Never dosage guidance, never "how to" — the product constitution rules those out
/// permanently, and the evidence says consequence information is associated with *smaller*
/// effects anyway (concept § 2.3, Black et al. 2016). This exists as a public-health and
/// emergency function, not as a reduction lever.
struct RiskInfo: Identifiable {
    let substanceName: String
    let dangers: String
    let avoidCombinations: [String]
    let emergencySymptoms: String
    let source: String

    var id: String { substanceName }
}

enum RiskInfoLibrary {
    static let entries: [RiskInfo] = [
        RiskInfo(
            substanceName: "Alkohol",
            dangers: "Atemdepression bei hohen Mengen. Erhöhtes Unfall- und Gewaltrisiko. Regelmäßiger Konsum belastet Leber, Herz und Schlaf; körperliche Abhängigkeit mit gefährlichem Entzug ist möglich.",
            avoidCombinations: [
                "Benzodiazepine, Opioide, Schlafmittel (Atemstillstand)",
                "GHB/GBL (Bewusstlosigkeit)"
            ],
            emergencySymptoms: "Nicht weckbar, flache Atmung, Unterkühlung, Erbrechen im Liegen → stabile Seitenlage und 112.",
            source: "BZgA · kenn-dein-limit.de"
        ),
        RiskInfo(
            substanceName: "Amphetamin",
            dangers: "Herz-Kreislauf-Belastung, Überhitzung, Schlafentzug. Bei häufigem Konsum psychische Folgen bis zu Psychosen; Reinheit und Streckmittel sind unbekannt.",
            avoidCombinations: [
                "MAO-Hemmer (lebensgefährlicher Blutdruckanstieg)",
                "Andere Stimulanzien (Herz-Kreislauf-Belastung)"
            ],
            emergencySymptoms: "Brustschmerz, sehr hohe Temperatur, Krampfanfall, Verwirrtheit → 112.",
            source: "BZgA · drugcom.de"
        ),
        RiskInfo(
            substanceName: "Cannabis",
            dangers: "Kreislaufprobleme, Angst und Panik, besonders bei hoher THC-Konzentration. Beeinträchtigt Reaktion und Gedächtnis; in jungen Jahren und bei Vorbelastung erhöhtes Psychose-Risiko.",
            avoidCombinations: [
                "Alkohol (Kreislaufkollaps, Erbrechen)",
                "Fahren oder Maschinen bedienen"
            ],
            emergencySymptoms: "Anhaltende Verwirrtheit, Bewusstlosigkeit, starke Herzrasen-Attacken → 112.",
            source: "BZgA · drugcom.de"
        ),
        RiskInfo(
            substanceName: "Ketamin",
            dangers: "Starke Beeinträchtigung von Motorik und Orientierung — Sturz-, Ertrinkungs- und Aspirationsgefahr. Häufiger Konsum schädigt die Blase dauerhaft.",
            avoidCombinations: [
                "Alkohol und andere dämpfende Substanzen (Atemdepression)",
                "Allein konsumieren"
            ],
            emergencySymptoms: "Nicht ansprechbar, Erbrechen im Liegen, flache Atmung → stabile Seitenlage und 112.",
            source: "mindzone.info · Saferparty"
        ),
        RiskInfo(
            substanceName: "Kokain",
            dangers: "Akute Herz-Kreislauf-Belastung bis Herzinfarkt und Schlaganfall — auch bei jungen, gesunden Menschen. Streckmittel sind die Regel, nicht die Ausnahme.",
            avoidCombinations: [
                "Alkohol (bildet Cocaethylen — deutlich herztoxischer)",
                "Andere Stimulanzien"
            ],
            emergencySymptoms: "Brustschmerz, Atemnot, Krampfanfall, halbseitige Lähmung → sofort 112.",
            source: "BZgA · drugcom.de"
        ),
        RiskInfo(
            substanceName: "MDMA",
            dangers: "Überhitzung und Dehydrierung, besonders beim Tanzen. Serotonin-Belastung; das Risiko steigt mit der Häufigkeit. Pausen zwischen Konsumereignissen sind der wichtigste Schutzfaktor.",
            avoidCombinations: [
                "MAO-Hemmer / bestimmte Antidepressiva (Serotonin-Syndrom)",
                "Amphetamine (Herz-Kreislauf-Belastung)"
            ],
            emergencySymptoms: "Sehr hohe Temperatur, Verwirrtheit, Krampfanfall → 112.",
            source: "BZgA · drugscouts.de"
        ),
        RiskInfo(
            substanceName: "Nikotin",
            dangers: "Stark abhängig machend. Rauchen schädigt Gefäße und Lunge dauerhaft; das Risiko sinkt ab dem ersten rauchfreien Tag messbar.",
            avoidCombinations: [
                "Kombination mit Cannabis erhöht die Abhängigkeitsentwicklung"
            ],
            emergencySymptoms: "Akute Notfälle sind selten. Anhaltender Brustschmerz oder Atemnot → 112.",
            source: "BZgA · rauchfrei-info.de"
        )
    ]

    static func info(for substanceName: String) -> RiskInfo? {
        entries.first { $0.substanceName.caseInsensitiveCompare(substanceName) == .orderedSame }
    }
}

// MARK: - Notfall (H3)

enum EmergencyContent {
    static let warningSigns = [
        "Bewusstlosigkeit, nicht weckbar",
        "Unregelmäßige oder flache Atmung",
        "Krampfanfall, blaue Lippen, Überhitzung"
    ]

    static let firstAidSteps = [
        "Stabile Seitenlage, Atemwege frei",
        "112 rufen — sag, was konsumiert wurde",
        "Bleib da, bis Hilfe eintrifft"
    ]

    static let emergencyNumber = "112"
}
