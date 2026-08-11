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
    /// Only ever read by `sensoryFeedback`, which needs an `Equatable` that changes.
    @State private var savedCount = 0

    private var hasSubstances: Bool { !activeSubstances.isEmpty }

    private var store: KlarStore { KlarStore(context: modelContext) }

    private enum Stage {
        case pickSubstance
        case saved(Entry)
        /// C3 — the entry pushed the user past their monthly limit.
        case overLimit(Entry, occasions: Int, limit: Int)
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
                EntryDetailForm(entry: entry, mode: .saved) { dismiss() }
            case .overLimit(let entry, let occasions, let limit):
                overLimitNotice(entry: entry, occasions: occasions, limit: limit)
            }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: savedCount)
        .sheet(isPresented: $isManagingSubstances) { SubstancesView() }
    }

    /// Each stage gets the height its own job needs.
    ///
    /// The detail form is the one screen that genuinely wants the room: at `.medium` the last
    /// field sat flush against the bottom edge, which reads as cut off even when it is not, and
    /// leaves nothing for large Dynamic Type to grow into. It goes full height and pins its
    /// „Fertig" to the bottom, so the extra height costs no reachability. Everything else stays
    /// short — the over-limit notice is a title and one card, and the empty picker is three lines
    /// and a button, where a taller sheet is just the same emptiness in a bigger box.
    private var detents: Set<PresentationDetent> {
        switch stage {
        case .saved: [.large]
        case .overLimit: [.medium, .large]
        case .pickSubstance: hasSubstances ? [.medium, .large] : [.height(230)]
        }
    }

    // MARK: - C1 · Substanz wählen

    /// The header is a real navigation bar, like both states that follow it.
    ///
    /// It used to be a `Text` in the content at 22pt with no toolbar at all, while saving jumped
    /// straight to a 34pt `navigationTitle` and produced a „Fertig" button out of nowhere. Three
    /// screens in one flow, two different header languages, and the seam sat exactly where the
    /// user is mid-task.
    ///
    /// No cancel button: this is a two-tap screen whose whole point is speed, and it already has
    /// two obvious ways out — the drag indicator and the page visible behind a sheet that never
    /// fills the screen. VoiceOver keeps its own escape gesture either way.
    private var substancePicker: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if hasSubstances {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(activeSubstances) { substance in
                                Button {
                                    save(substance)
                                } label: {
                                    substanceRow(substance)
                                }
                                .klarRowButtonStyle()
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
            .padding(.top, Klar.Space.x2)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Neuer Eintrag")
            .navigationSubtitle(
                hasSubstances
                    ? "Tippen genügt. Details kannst du später ergänzen."
                    : "Noch keine Substanz ausgewählt."
            )
        }
        // Grouped-page background, not a plain white sheet: the substance rows below are cards,
        // and a card needs something to sit *on* now that it no longer carries an outline.
        .background(Klar.bgSubtle)
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
    }

    private func save(_ substance: Substance) {
        let entry = store.addEntry(substance: substance, timestamp: timestamp)

        let quota = store.quota(for: substance, on: timestamp)
        if let limit = quota.limit, quota.occasions > limit {
            stage = .overLimit(entry, occasions: quota.occasions, limit: limit)
        } else {
            stage = .saved(entry)
        }
        // Deliberately the same tick either way. It confirms that the tap landed, and it must
        // not become a second channel that comments on the limit — the over-limit screen is
        // already written to state the fact and stop (P7).
        savedCount += 1
    }

    // MARK: - C3 · Über dem Limit

    /// Factual, never punitive. No red, no warning icon, no appeal to do better. The entry is
    /// simply stated.
    private func overLimitNotice(entry: Entry, occasions: Int, limit: Int) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                KlarCard {
                    Text("Eintrag \(occasions) von max. \(limit) diesen Monat.")
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                        .padding(.bottom, 6)
                    Text("Steht so in deinem Verlauf. Ehrliche Daten sind wertvoller als eingehaltene Zahlen.")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, Klar.Space.x2)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Klar.bgSubtle)
            .navigationTitle("Gespeichert.")
            .navigationSubtitle(EntryStamp.subtitle(for: entry, isFresh: true))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

// MARK: - C2 · Gespeichert + Details

/// What the entry is and when it landed — "Alkohol · jetzt, 19:53".
///
/// This used to sit in a `SavedHeader` view: a green check in a circle next to a bold
/// "Gespeichert." line, with the form starting immediately underneath. It confirmed nothing the
/// haptic had not already confirmed, and it occupied the position a title belongs in without
/// being one. Both screens now put the word in the sheet's `navigationTitle` and this line in
/// its `navigationSubtitle`, which is where iOS puts exactly this pair.
enum EntryStamp {
    /// - Parameter isFresh: whether the entry was written *by this screen, a moment ago*. Only
    ///   then does „jetzt" mean anything.
    ///
    ///   It used to be inferred from `isToday`, which made every entry logged earlier today read
    ///   „jetzt" — an entry from 08:05 announced itself as happening now when you opened it at
    ///   20:44. That was survivable while the line was small grey text inside a badge; as the
    ///   sheet's subtitle under a large title it is simply wrong. The caller knows which case it
    ///   is, so it says so rather than the string guessing from the clock.
    static func subtitle(for entry: Entry, isFresh: Bool = false) -> String {
        let name = entry.substance?.name ?? "Eintrag"
        let time = KlarDate.time(entry.timestamp)
        guard KlarDate.isToday(entry.timestamp, timezoneID: entry.timezoneID) else {
            return "\(name) · \(KlarDate.dayAndMonth(entry.timestamp)), \(time)"
        }

        let when = isFresh ? "jetzt, \(time)" : time

        // Logged after midnight: the day this lands on is not the one the phone's clock shows.
        // This is the moment a wrong assumption costs the user an action, so the day gets named
        // here rather than only in the Übersicht header behind the sheet.
        guard KlarDate.isBeforeCutoff(entry.timestamp, timezoneID: entry.timezoneID) else {
            return "\(name) · \(when)"
        }
        let day = KlarDate.weekdayName(
            KlarDate.logicalDay(for: entry.timestamp, timezoneID: entry.timezoneID)
        )
        return "\(name) · \(when) · noch \(day)"
    }
}

/// The optional-detail form. Shared by the post-save state (C2) and by editing an existing
/// entry from Today or the day detail (E2) — same fields, same rules.
struct EntryDetailForm: View {
    /// The same fields serve two different jobs, and everything that differs between the two
    /// follows from which one it is — rather than from three booleans that could be set into
    /// combinations that make no sense.
    enum Mode {
        /// The step straight after saving. A flow with a terminal action, so „Fertig" is a
        /// prominent button pinned to the bottom, and the sheet opens at full height because
        /// there is nothing left to come back to.
        case saved
        /// An existing entry opened to be looked at or adjusted. Every field writes as it is
        /// changed, so there is nothing to commit — „Fertig" only closes, which is what a
        /// toolbar button says and a big primary button would overstate.
        case edit

        var title: LocalizedStringKey {
            switch self {
            case .saved: "Gespeichert."
            case .edit: "Eintrag"
            }
        }

        /// Only the screen that just wrote the entry may claim it happened „jetzt".
        var isFresh: Bool { self == .saved }

        /// Deleting something one second after creating it is the undo of a tap, not a decision
        /// worth a destructive control; the picker is still one swipe away.
        var showsDelete: Bool { self == .edit }
    }

    let entry: Entry
    var mode: Mode = .edit
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

    /// Stands in for „nothing picked" inside the segmented control, which needs a non-optional
    /// selection. Out of range of the real scale, so it can never collide with a stored mood.
    private static let noMood = Int.min

    private var moodOptions: [(value: Int, label: String)] {
        moods
    }

    /// Mood is optional and stays optional: tapping the segment that is already on clears it
    /// rather than being a no-op, which is the only way to take a mood back.
    private func setMood(_ value: Int) {
        mood = (mood == value) ? nil : value
        store.updateEntry(entry, mood: .some(mood))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    KlarSectionLabel(text: "Dosis (optional)", color: Klar.textSecondary)
                        .padding(.bottom, 8)

                    // The one border that stays. iOS outlines text fields — they are controls,
                    // and a control has to look like something you can put a cursor in.
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
                    .padding(.bottom, 20)

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
                    .padding(.bottom, 20)

                    KlarSectionLabel(text: "Stimmung (optional)", color: Klar.textSecondary)
                        .padding(.bottom, 8)

                    // Was three hand-drawn outlined buttons. This is the design system's own
                    // segmented control, the same one Verlauf and the goal editor use — and it
                    // keeps the "tap again to clear" behaviour a real `Picker` cannot express.
                    KlarSegmentedControl(
                        options: moodOptions,
                        selection: Binding(
                            get: { mood ?? Self.noMood },
                            set: { setMood($0) }
                        )
                    )
                    .padding(.bottom, 20)

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

                    if mode.showsDelete {
                        Button("Eintrag löschen", role: .destructive) {
                            isConfirmingDelete = true
                        }
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, Klar.Space.x2)
                .padding(.bottom, mode == .saved ? Klar.Space.x4 : 34)
            }
            .scrollIndicators(.hidden)
            // Grouped page, not the card colour. On `Klar.surface` every field had to be outlined
            // just to be visible against its own background — which is how the borders survived
            // here after being removed everywhere else.
            .background(Klar.bgSubtle)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(mode.title)
            .navigationSubtitle(EntryStamp.subtitle(for: entry, isFresh: mode.isFresh))
            .safeAreaBar(edge: .bottom) {
                if mode == .saved {
                    // Pinned, so it is reachable whatever the fields below have grown to, and
                    // prominent, because ending the flow is the one thing this screen is for.
                    // The bar takes part in the safe area, so the scroll content ends above it
                    // rather than behind it.
                    KlarPrimaryButton(title: "Fertig", action: onDone)
                        .padding(.horizontal, 20)
                        .padding(.bottom, Klar.Space.x2)
                }
            }
            .toolbar {
                if mode == .edit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig", action: onDone)
                    }
                }
            }
        }
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
        EntryDetailForm(entry: entry, mode: .edit) {
            dismiss()
        }
        // Full height, because „Eintrag löschen" sits under the last field and at `.medium` it
        // fell off the bottom edge — a destructive action you have to go looking for is one
        // nobody finds. Still a sheet rather than a `fullScreenCover`: swiping down is how you
        // leave an inspector, and the covers in this app are the guided moments (review, SOS,
        // breathing) you are deliberately not meant to leave by accident.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
