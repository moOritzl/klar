import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// „Daten" — the promise in A1 made operable.
///
/// Export is complete (the JSON round-trips back in through the import below), and deletion is
/// real deletion, not a flag. An app whose whole pitch is "nothing to compromise" has to make all
/// three trivially reachable.
struct DataManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @State private var exportDocument: ExportDocument?
    @State private var isExportingJSON = false
    @State private var isConfirmingWipe = false
    @State private var isImporting = false
    @State private var pendingImport: Data?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Klar.bgSubtle.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        KlarGroupHeader(text: "Export")
                            .padding(.bottom, 8)

                        SettingsGroup {
                            SettingsNavigationRow(
                                icon: "square.and.arrow.up",
                                title: "Daten exportieren"
                            ) { exportJSON() }
                        }
                        .padding(.bottom, 20)

                        KlarGroupHeader(text: "Import")
                            .padding(.bottom, 8)

                        SettingsGroup {
                            SettingsNavigationRow(
                                icon: "square.and.arrow.down",
                                title: "Daten importieren",
                                subtitle: "Ersetzt alle Daten auf diesem Gerät"
                            ) { isImporting = true }
                        }
                        .padding(.bottom, 20)

                        KlarGroupHeader(text: "Löschen")
                            .padding(.bottom, 8)

                        Button {
                            isConfirmingWipe = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash")
                                    .font(.system(size: 15))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Alle Daten löschen")
                                        .font(Klar.TypeScale.body.weight(.semibold))
                                    Text("Endgültig. Kein Papierkorb, keine Kopie auf einem Server.")
                                        .font(Klar.TypeScale.caption)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                            }
                            .foregroundStyle(Klar.danger)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Klar.dangerTint)
                            .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous)
                                    .strokeBorder(Klar.danger, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 20)

                        Text("Der Export enthält deine Einträge, Ziele, Pläne und Notizen. Er enthält keine Gerätedaten: Face-ID-Einstellung und Vertrauensperson bleiben auf diesem Gerät.")
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.textTertiary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Daten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .fileExporter(
            isPresented: $isExportingJSON,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "klar-export-\(filenameStamp)"
        ) { handle($0) }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                loadForImport(url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Alle Daten ersetzen?",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ersetzen", role: .destructive) { performImport() }
            Button("Abbrechen", role: .cancel) { pendingImport = nil }
        } message: {
            Text("Einträge, Ziele, Pläne und Notizen auf diesem Gerät werden durch die Datei ersetzt.")
        }
        .confirmationDialog(
            "Wirklich alle Daten löschen?",
            isPresented: $isConfirmingWipe,
            titleVisibility: .visible
        ) {
            Button("Endgültig löschen", role: .destructive) { wipe() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Einträge, Ziele, Pläne und Notizen werden entfernt. Das lässt sich nicht rückgängig machen.")
        }
        .alert(
            "Das hat nicht geklappt",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var filenameStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func exportJSON() {
        do {
            let data = try ExportImportService.exportJSON(context: modelContext)
            exportDocument = ExportDocument(data: data)
            isExportingJSON = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reads and validates before anything is destroyed. A file that cannot be decoded never
    /// reaches the confirmation dialog, so the user is never asked to approve a wipe that would
    /// then fail halfway.
    private func loadForImport(_ url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            _ = try ExportImportService.decode(data)
            pendingImport = data
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performImport() {
        guard let data = pendingImport else { return }
        pendingImport = nil
        do {
            try ExportImportService.replaceAll(with: data, context: modelContext)
            // Without this the user lands back in onboarding on top of a full store.
            settings.hasCompletedOnboarding = true
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handle(_ result: Result<URL, Error>) {
        exportDocument = nil
        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes the store *and* resets the device-side settings, then drops the user back into
    /// onboarding — otherwise they'd land on a Today screen with no substances and no way to
    /// pick any.
    private func wipe() {
        do {
            try ExportImportService.wipeAll(context: modelContext)
            try ContextTagSeeder.seedIfNeeded(context: modelContext)
            settings.supportContactName = nil
            settings.supportContactPhone = nil
            settings.resetForOnboarding()
            NotificationScheduler.cancelAll()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Bridges raw `Data` into `fileExporter`.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
