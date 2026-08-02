import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import KlarCore

struct DebugRootView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var statusMessage: String?
    @State private var quotaSummary: String?
    @State private var statsSummary: String?
    @State private var exportedJSONURL: URL?
    @State private var showWipeConfirmation1 = false
    @State private var showWipeConfirmation2 = false
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            List {
                Section("Daten") {
                    Button("Demodaten einspielen") { seedDemoData() }
                    Button("Quote für aktuellen Monat anzeigen") { showQuota() }
                    Button("Statistik-Zusammenfassung anzeigen") { showStats() }
                }

                Section("Export") {
                    Button("Als JSON exportieren") { exportJSON() }
                    if let exportedJSONURL {
                        ShareLink(item: exportedJSONURL) {
                            Label("JSON teilen", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section("Import") {
                    Button("JSON importieren") { showImporter = true }
                }

                Section("Löschen") {
                    Button("Alle Daten löschen", role: .destructive) { showWipeConfirmation1 = true }
                }

                if let quotaSummary {
                    Section("Quote") { Text(quotaSummary) }
                }
                if let statsSummary {
                    Section("Statistik") { Text(statsSummary) }
                }
                if let statusMessage {
                    Section("Status") { Text(statusMessage) }
                }
            }
            .navigationTitle("Klar – Debug")
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Wirklich alle Daten löschen?", isPresented: $showWipeConfirmation1) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) { showWipeConfirmation2 = true }
            }
            .alert("Bist du sicher? Das kann nicht rückgängig gemacht werden.", isPresented: $showWipeConfirmation2) {
                Button("Abbrechen", role: .cancel) {}
                Button("Endgültig löschen", role: .destructive) { wipeAll() }
            }
        }
    }

    private func seedDemoData() {
        do {
            try DemoDataSeeder.seed(context: modelContext)
            statusMessage = "Demodaten eingespielt."
        } catch {
            statusMessage = "Fehler beim Einspielen: \(error.localizedDescription)"
        }
    }

    private func showQuota() {
        do {
            let substances = try modelContext.fetch(FetchDescriptor<Substance>())
            let entryDTOs = try modelContext.fetch(FetchDescriptor<Entry>()).map { $0.toDTO() }
            let goalDTOs = try modelContext.fetch(FetchDescriptor<GoalPeriod>()).map { $0.toDTO() }

            let calendar = Calendar(identifier: .gregorian)
            let now = Date()
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)

            let lines = substances.map { substance -> String in
                let result = QuotaCalculator.quota(entries: entryDTOs, substanceID: substance.id, goalPeriods: goalDTOs, year: year, month: month, timezoneID: "Europe/Berlin")
                let limitText = result.limit.map(String.init) ?? "–"
                let remainingText = result.remaining.map(String.init) ?? "–"
                return "\(substance.name): \(result.occasions) Anlässe, Limit \(limitText), verbleibend \(remainingText)"
            }
            quotaSummary = lines.joined(separator: "\n")
        } catch {
            statusMessage = "Fehler: \(error.localizedDescription)"
        }
    }

    private func showStats() {
        do {
            let substances = try modelContext.fetch(FetchDescriptor<Substance>())
            let entryDTOs = try modelContext.fetch(FetchDescriptor<Entry>()).map { $0.toDTO() }

            let lines = substances.map { substance -> String in
                let summary = StatsCalculator.summary(entries: entryDTOs, substanceID: substance.id, referenceTimezoneID: "Europe/Berlin")
                let daysSinceText = summary.daysSinceLastOccasion.map(String.init) ?? "–"
                return "\(substance.name): \(summary.weeklyAverages.count) Wochen erfasst, Tage seit letztem Eintrag: \(daysSinceText)"
            }
            statsSummary = lines.joined(separator: "\n")
        } catch {
            statusMessage = "Fehler: \(error.localizedDescription)"
        }
    }

    private func exportJSON() {
        do {
            let data = try ExportImportService.exportJSON(context: modelContext)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("klar-export-\(Int(Date().timeIntervalSince1970)).json")
            try data.write(to: url)
            exportedJSONURL = url
            statusMessage = "JSON-Export bereit."
        } catch {
            statusMessage = "Fehler beim Export: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            try ExportImportService.importJSON(data, context: modelContext)
            statusMessage = "Import erfolgreich."
        } catch {
            statusMessage = "Fehler beim Import: \(error.localizedDescription)"
        }
    }

    private func wipeAll() {
        do {
            try ExportImportService.wipeAll(context: modelContext)
            statusMessage = "Alle Daten gelöscht."
            quotaSummary = nil
            statsSummary = nil
        } catch {
            statusMessage = "Fehler beim Löschen: \(error.localizedDescription)"
        }
    }
}

#Preview {
    DebugRootView()
        .modelContainer(for: [
            Substance.self, Entry.self, ContextTag.self, GoalPeriod.self, Plan.self,
            PlanCheckIn.self, SubstitutionAction.self, WhyNote.self, ReviewDecision.self
        ], inMemory: true)
}
