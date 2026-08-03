import SwiftUI
import SwiftData
import KlarCore

/// C1–C3 · Flow „Eintrag erfassen".
///
/// Two taps to "gespeichert". The entry is written the instant a substance is tapped — there is
/// no confirmation step and no "Bist du sicher?", because shame is the enemy of data quality.
/// Everything after the save (dose, context, mood) is optional and can be filled in later.
struct EntrySheetView: View {
    /// Pre-dates the entry — used when adding an entry to a past day from the day detail (E2).
    var timestamp: Date = Date()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var substances: [Substance]

    @State private var stage: Stage = .pickSubstance
    @State private var isManagingSubstances = false

    private var hasSubstances: Bool { !activeSubstances.isEmpty }

    private var store: KlarStore { KlarStore(context: modelContext) }

    private enum Stage {
        case pickSubstance
        case saved(Entry)
        /// C3 — the entry pushed the user past their monthly limit.
        case overLimit(Entry, occasions: Int, limit: Int)

        /// The picker is a half-sheet; both post-save states need the full height.
        var isPicker: Bool {
            if case .pickSubstance = self { return true }
            return false
        }
    }

    private var activeSubstances: [Substance] {
        substances.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        Group {
            switch stage {
            case .pickSubstance:
                substancePicker
            case .saved(let entry):
                EntryDetailForm(entry: entry, title: "Gespeichert.") { dismiss() }
            case .overLimit(let entry, let occasions, let limit):
                overLimitNotice(entry: entry, occasions: occasions, limit: limit)
            }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isManagingSubstances) { SubstancesView() }
    }

    /// The empty state is three lines and a button; a half-screen detent around it is the
    /// "spacing" complaint.
    private var detents: Set<PresentationDetent> {
        guard stage.isPicker else { return [.large] }
        // 300 still left ~140pt of nothing under the button, which is the same complaint in a
        // smaller box. The empty state measures ~170pt including padding.
        return hasSubstances ? [.medium, .large] : [.height(230)]
    }

    // MARK: - C1 · Substanz wählen

    private var substancePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Eintrag")
                .font(Klar.TypeScale.title)
                .foregroundStyle(Klar.text)
                .padding(.bottom, 4)

            Text(hasSubstances
                 ? "Tippen genügt. Details kannst du später ergänzen."
                 : "Noch keine Substanz ausgewählt.")
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textTertiary)
                .padding(.bottom, 18)

            if hasSubstances {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(activeSubstances) { substance in
                            Button {
                                save(substance)
                            } label: {
                                substanceRow(substance)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                // Pointing at Einstellungen and leaving the user to find it was the old copy.
                // The button is the same distance away and does not have to be searched for.
                KlarPrimaryButton(title: "Substanzen auswählen") {
                    isManagingSubstances = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Klar.surface)
    }

    private func substanceRow(_ substance: Substance) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Klar.substanceColor(substance.colorIndex))
                .frame(width: 12, height: 12)
            Text(substance.name)
                .font(Klar.TypeScale.body)
                .foregroundStyle(Klar.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Klar.surface)
        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous)
                .strokeBorder(Klar.border, lineWidth: 1)
        }
    }

    private func save(_ substance: Substance) {
        let entry = store.addEntry(substance: substance, timestamp: timestamp)

        let quota = store.quota(for: substance, on: timestamp)
        if let limit = quota.limit, quota.occasions > limit {
            stage = .overLimit(entry, occasions: quota.occasions, limit: limit)
        } else {
            stage = .saved(entry)
        }
    }

    // MARK: - C3 · Über dem Limit

    /// Factual, never punitive. No red, no warning icon, no appeal to do better. The entry is
    /// simply stated.
    private func overLimitNotice(entry: Entry, occasions: Int, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SavedHeader(entry: entry)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("Eintrag \(occasions) von max. \(limit) diesen Monat.")
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
                Text("Steht so in deinem Verlauf. Ehrliche Daten sind wertvoller als eingehaltene Zahlen.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Klar.bgSubtle)
            .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous)
                    .strokeBorder(Klar.border, lineWidth: 1)
            }
            .padding(.bottom, 18)

            Spacer()

            KlarQuietButton(title: "Schließen") { dismiss() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Klar.surface)
    }
}

// MARK: - C2 · Gespeichert + Details

/// The "Gespeichert." confirmation with a green check — the only celebratory-looking moment in
/// the app, and it celebrates the *logging*, never the consumption.
struct SavedHeader: View {
    let entry: Entry
    var title: LocalizedStringKey = "Gespeichert."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Klar.accentStrong)
                .frame(width: 34, height: 34)
                .background(Klar.accentTint, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Klar.TypeScale.headline)
                    .foregroundStyle(Klar.text)
                Text(subtitle)
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }
            Spacer()
        }
    }

    private var subtitle: String {
        let name = entry.substance?.name ?? "Eintrag"
        let time = KlarDate.time(entry.timestamp)
        guard KlarDate.isToday(entry.timestamp, timezoneID: entry.timezoneID) else {
            return "\(name) · \(KlarDate.dayAndMonth(entry.timestamp)), \(time)"
        }
        // Logged after midnight: „jetzt" is true, but the day this lands on is not the one the
        // phone's clock shows. This is the moment a wrong assumption costs the user an action, so
        // the day gets named here rather than only in the Heute header behind the sheet.
        guard KlarDate.isBeforeCutoff(entry.timestamp, timezoneID: entry.timezoneID) else {
            return "\(name) · jetzt, \(time)"
        }
        let day = KlarDate.weekdayName(
            KlarDate.logicalDay(for: entry.timestamp, timezoneID: entry.timezoneID)
        )
        return "\(name) · jetzt, \(time) · noch \(day)"
    }
}

/// The optional-detail form. Shared by the post-save state (C2) and by editing an existing
/// entry from Today or the day detail (E2) — same fields, same rules.
struct EntryDetailForm: View {
    let entry: Entry
    var title: LocalizedStringKey = "Eintrag"
    var showsDelete: Bool = false
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var contextTags: [ContextTag]

    @State private var amountText = ""
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var mood: Int?
    @State private var timestamp = Date()
    @State private var isConfirmingDelete = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    private var sortedTags: [ContextTag] {
        contextTags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// 1 = Gut, 0 = Neutral, -1 = Mies. Stored as an Int so the scale can widen later without
    /// a migration.
    private let moods: [(value: Int, label: String)] = [
        (1, "Gut"), (0, "Neutral"), (-1, "Mies")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SavedHeader(entry: entry, title: title)
                    .padding(.bottom, 18)

                KlarSectionLabel(text: "Dosis (optional)", color: Klar.textSecondary)
                    .padding(.bottom, 8)

                HStack {
                    TextField("Überspringbar", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                        .onChange(of: amountText) { _, _ in commitAmount() }
                    Text(entry.substance?.unit.shortLabel ?? "")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Klar.surface)
                .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous)
                        .strokeBorder(Klar.border, lineWidth: 1)
                }
                .padding(.bottom, 16)

                KlarSectionLabel(text: "Kontext (optional)", color: Klar.textSecondary)
                    .padding(.bottom, 8)

                KlarFlowLayout(spacing: 8) {
                    ForEach(sortedTags) { tag in
                        Button {
                            toggleTag(tag)
                        } label: {
                            KlarChip(text: tag.name, isSelected: selectedTagIDs.contains(tag.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 16)

                KlarSectionLabel(text: "Stimmung (optional)", color: Klar.textSecondary)
                    .padding(.bottom, 8)

                HStack(spacing: 8) {
                    ForEach(moods, id: \.value) { option in
                        Button {
                            mood = (mood == option.value) ? nil : option.value
                            store.updateEntry(entry, mood: .some(mood))
                        } label: {
                            Text(option.label)
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(mood == option.value ? .white : Klar.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(mood == option.value ? Klar.accent : Klar.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous)
                                        .strokeBorder(
                                            mood == option.value ? Color.clear : Klar.border,
                                            lineWidth: 1
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 16)

                KlarSectionLabel(text: "Zeitpunkt", color: Klar.textSecondary)
                    .padding(.bottom, 8)

                DatePicker(
                    "Zeitpunkt",
                    selection: $timestamp,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .onChange(of: timestamp) { _, newValue in
                    store.updateEntry(entry, timestamp: newValue)
                }
                .padding(.bottom, 20)

                if showsDelete {
                    Button("Eintrag löschen", role: .destructive) {
                        isConfirmingDelete = true
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Klar.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)
                }

                KlarQuietButton(title: "Fertig", action: onDone)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(Klar.surface)
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog(
            "Eintrag löschen?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                store.deleteEntry(entry)
                onDone()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der Eintrag wird endgültig entfernt.")
        }
        .task {
            amountText = entry.amount?.klarFormatted ?? ""
            selectedTagIDs = Set((entry.contextTags ?? []).map(\.id))
            mood = entry.mood
            timestamp = entry.timestamp
        }
    }

    private func commitAmount() {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        let value = normalized.isEmpty ? nil : Decimal(string: normalized)
        store.updateEntry(entry, amount: .some(value))
    }

    private func toggleTag(_ tag: ContextTag) {
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else {
            selectedTagIDs.insert(tag.id)
        }
        let tags = sortedTags.filter { selectedTagIDs.contains($0.id) }
        store.updateEntry(entry, contextTags: tags)
    }
}

/// Editing an already-saved entry (from Today, or from the day detail E2).
struct EntryDetailSheet: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EntryDetailForm(entry: entry, title: "Eintrag", showsDelete: true) {
            dismiss()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
