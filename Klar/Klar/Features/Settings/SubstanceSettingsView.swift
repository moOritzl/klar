import SwiftUI
import SwiftData
import KlarCore

/// Einstellungen › Substanzen › one substance. Everything decided once per substance, in one
/// place: its limit, whether „Der Morgen danach" asks about it, its cost basis, archiving.
struct SubstanceSettingsView: View {
    let substance: Substance

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Unread: redraws `LimitEditor` when a goal is versioned. See its doc comment.
    @Query private var goalPeriods: [GoalPeriod]

    @State private var costText = ""
    @State private var isConfirmingArchive = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KlarCard(padding: 16) {
                    LimitEditor(substance: substance, store: store)
                }

                SettingsGroup {
                    SettingsToggleRow(
                        icon: "sunrise",
                        title: "Morgen danach fragen",
                        subtitle: "Eine kurze Karte am Morgen nach einem Tag mit Einträgen",
                        isOn: Binding(
                            get: { substance.asksMorningAfter },
                            set: { store.setAsksMorningAfter($0, for: substance) }
                        )
                    )
                    .accessibilityIdentifier("settings.asksMorningAfter.\(substance.name)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    SettingsGroup {
                        HStack(spacing: 12) {
                            Image(systemName: "eurosign")
                                .font(.system(size: 15))
                                .foregroundStyle(Klar.textSecondary)
                                .frame(width: 18)
                            Text("Kosten je \(substance.unit.shortLabel)")
                                .font(Klar.TypeScale.body)
                                .foregroundStyle(Klar.text)
                            Spacer()
                            TextField("—", text: $costText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(Klar.TypeScale.body)
                                .frame(width: 70)
                                .onChange(of: costText) { _, newValue in
                                    let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                                    substance.costPerUnit = normalized.isEmpty ? nil : Decimal(string: normalized)
                                }
                            Text("€")
                                .font(Klar.TypeScale.body)
                                .foregroundStyle(Klar.textTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                    Text("Die Kostenbasis ist deine eigene Schätzung. Sie speist die „Geld gespart“-Rechnung.")
                        .font(Klar.TypeScale.caption)
                        .foregroundStyle(Klar.textTertiary)
                        .padding(.horizontal, 4)
                }

                KlarQuietButton(title: "Archivieren") {
                    isConfirmingArchive = true
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, Klar.Space.x2)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Klar.bgSubtle)
        .navigationTitle(substance.name)
        .confirmationDialog(
            "„\(substance.name)“ archivieren?",
            isPresented: $isConfirmingArchive,
            titleVisibility: .visible
        ) {
            Button("Archivieren") {
                store.archiveSubstance(substance)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Bestehende Einträge bleiben erhalten. Die Substanz verschwindet nur aus der Auswahl.")
        }
        .task {
            costText = substance.costPerUnit?.klarFormatted ?? ""
        }
    }
}
