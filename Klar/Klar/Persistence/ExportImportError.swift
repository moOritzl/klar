import Foundation

enum ExportImportError: Error, LocalizedError, Equatable {
    case storeNotEmpty
    case unknownSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .storeNotEmpty:
            return String(localized: "Import ist nur in eine leere Datenbank möglich.")
        case .unknownSchemaVersion(let version):
            return String(localized: "Unbekannte Schemaversion: \(version)")
        }
    }
}
