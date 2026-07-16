import SwiftUI
import SwiftData
import KlarCore

/// A1–A4. A one-time, four-step flow whose job is to establish trust *before* anything is
/// recorded. Nothing is written to the store until the final step — abandoning halfway leaves
/// no trace.
struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @State private var step = 0
    @State private var draft = OnboardingDraft()

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        ZStack {
            switch step {
            case 0:
                PrivacyStepView(draft: draft) { advance() }
            case 1:
                SubstanceSelectionStepView(draft: draft) { advance() }
            case 2:
                GoalStepView(draft: draft) { advance() }
            default:
                SubstitutionStepView(draft: draft) { finish() }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    private func advance() {
        step += 1
    }

    private func finish() {
        draft.commit(to: store)
        settings.isAppLockEnabled = draft.enableAppLock
        settings.hasCompletedOnboarding = true
    }
}

// MARK: - Draft

/// Everything the flow gathers, held in memory until "Fertig — App öffnen".
@Observable
final class OnboardingDraft {
    var enableAppLock = false
    var selectedTemplates: Set<SubstanceTemplate> = []
    var customSubstanceNames: [String] = []

    /// Keyed by substance name — the draft has no IDs yet.
    var goalTypes: [String: GoalType] = [:]
    var monthlyLimits: [String: Int] = [:]

    var substitutionActions: [String] = []

    /// Selected substances in the order they'll be created, alphabetically like the picker.
    ///
    /// `selectedTemplates` already contains custom substances (`addCustom` inserts into both
    /// collections so the A2 checkbox shows them as checked) — `customSubstanceNames` must not
    /// be merged in again here, or custom substances get created twice.
    var chosenSubstances: [SubstanceTemplate] {
        selectedTemplates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func goalType(for substance: SubstanceTemplate) -> GoalType {
        goalTypes[substance.name] ?? .observe
    }

    func monthlyLimit(for substance: SubstanceTemplate) -> Int {
        monthlyLimits[substance.name] ?? 4
    }

    @MainActor
    func commit(to store: KlarStore) {
        for template in chosenSubstances {
            let substance = store.addSubstance(name: template.name, unit: template.unit)
            let type = goalType(for: template)
            store.setGoal(
                for: substance,
                type: type,
                monthlyLimit: type == .reduction ? monthlyLimit(for: template) : nil
            )
        }
        for text in substitutionActions where !text.trimmingCharacters(in: .whitespaces).isEmpty {
            store.addSubstitutionAction(text: text)
        }
    }
}

// MARK: - A1 · Privatsphäre

struct PrivacyStepView: View {
    let draft: OnboardingDraft
    let onContinue: () -> Void

    @State private var isAuthenticating = false

    private var canUseBiometrics: Bool { AppLockManager.canAuthenticate() }

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("KLAR")
                    .font(Klar.TypeScale.display(15))
                    .tracking(15 * 0.42)
                    .foregroundStyle(Klar.textTertiary)
                    .frame(maxWidth: .infinity)

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Klar.accent)
                    .frame(width: 64, height: 64)
                    .background(Klar.accentTint, in: Circle())
                    .padding(.bottom, 28)

                Text("Alles bleibt auf deinem Gerät.")
                    .font(Klar.TypeScale.display(30))
                    .foregroundStyle(Klar.text)
                    .padding(.bottom, 14)

                Text("Kein Account. Keine Registrierung. Kein Server. Nichts, was kompromittiert werden könnte. Deine Ehrlichkeit gehört nur dir.")
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.textSecondary)
                    .padding(.bottom, 24)

                if canUseBiometrics {
                    HStack(spacing: 12) {
                        Image(systemName: "faceid")
                            .font(.system(size: 18))
                            .foregroundStyle(Klar.textSecondary)
                        Text("Mit Face ID sichern")
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.text)
                        Spacer()
                        if draft.enableAppLock {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Klar.accentStrong)
                        }
                    }
                    .padding(16)
                    .background(Klar.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous)
                            .strokeBorder(Klar.border, lineWidth: 1)
                    }
                }

                Spacer()

                if canUseBiometrics {
                    KlarPrimaryButton(
                        title: draft.enableAppLock ? "Weiter" : "Face ID einrichten",
                        isEnabled: !isAuthenticating
                    ) {
                        if draft.enableAppLock {
                            onContinue()
                        } else {
                            Task { await enableLock() }
                        }
                    }
                    .padding(.bottom, 12)

                    Button("Später einrichten") { onContinue() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Klar.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                } else {
                    // No Face ID / passcode on this device: don't dangle a lock we can't deliver.
                    KlarPrimaryButton(title: "Weiter") { onContinue() }
                        .padding(.bottom, 16)
                }

                KlarStepDots(count: 4, current: 0)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
    }

    /// Prove the lock works *now*, so the user never discovers at the worst moment that it doesn't.
    private func enableLock() async {
        isAuthenticating = true
        defer { isAuthenticating = false }

        let manager = AppLockManager()
        let success = await manager.attemptUnlock()
        if success {
            draft.enableAppLock = true
            onContinue()
        }
    }
}

// MARK: - A2 · Substanzauswahl

struct SubstanceSelectionStepView: View {
    let draft: OnboardingDraft
    let onContinue: () -> Void

    @State private var isAddingCustom = false
    @State private var customName = ""

    private var rows: [SubstanceTemplate] {
        SubstanceCatalog.starters + draft.customSubstanceNames.map {
            SubstanceTemplate(name: $0, unit: .piece)
        }
    }

    var body: some View {
        OnboardingScaffold(
            title: "Was möchtest du erfassen?",
            subtitle: "Alphabetisch, ohne Wertung. Mehrfachauswahl. Jederzeit änderbar — die Auswahl ist kein Bekenntnis.",
            step: 1,
            primaryTitle: "Weiter",
            isPrimaryEnabled: !draft.chosenSubstances.isEmpty,
            onPrimary: onContinue
        ) {
            VStack(spacing: 2) {
                ForEach(rows.sorted(by: { $0.name < $1.name })) { template in
                    Button {
                        toggle(template)
                    } label: {
                        HStack {
                            Text(template.name)
                                .font(Klar.TypeScale.body)
                                .foregroundStyle(Klar.text)
                            Spacer()
                            checkbox(isOn: draft.selectedTemplates.contains(template))
                        }
                        .padding(.vertical, 15)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Klar.borderSubtle)
                }

                Button {
                    isAddingCustom = true
                } label: {
                    HStack {
                        Text("Eigene hinzufügen")
                            .font(Klar.TypeScale.body)
                            .foregroundStyle(Klar.accentStrong)
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Klar.accentStrong)
                    }
                    .padding(.vertical, 15)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .alert("Eigene Substanz", isPresented: $isAddingCustom) {
            TextField("Name", text: $customName)
            Button("Abbrechen", role: .cancel) { customName = "" }
            Button("Hinzufügen") { addCustom() }
        }
    }

    private func checkbox(isOn: Bool) -> some View {
        Group {
            if isOn {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Klar.accent)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Klar.borderStrong, lineWidth: 1.5)
            }
        }
        .frame(width: 24, height: 24)
    }

    private func toggle(_ template: SubstanceTemplate) {
        if draft.selectedTemplates.contains(template) {
            draft.selectedTemplates.remove(template)
        } else {
            draft.selectedTemplates.insert(template)
        }
    }

    private func addCustom() {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        customName = ""
        guard !name.isEmpty,
              !SubstanceCatalog.starters.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }),
              !draft.customSubstanceNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })
        else { return }

        draft.customSubstanceNames.append(name)
        draft.selectedTemplates.insert(SubstanceTemplate(name: name, unit: .piece))
    }
}

// MARK: - A3 · Ziel je Substanz

struct GoalStepView: View {
    let draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "Was ist dein Ziel?",
            subtitle: "Kein Ziel am Tag 1 nötig. „Nur beobachten“ ist Stufe 1 — anfangen darfst du trotzdem.",
            step: 2,
            primaryTitle: "Weiter",
            onPrimary: onContinue
        ) {
            VStack(spacing: 14) {
                ForEach(draft.chosenSubstances) { substance in
                    goalCard(for: substance)
                }
            }
        }
    }

    private func goalCard(for substance: SubstanceTemplate) -> some View {
        KlarCard(padding: 16) {
            Text(substance.name)
                .font(Klar.TypeScale.headline)
                .foregroundStyle(Klar.text)
                .padding(.bottom, 12)

            KlarSegmentedControl(
                options: [
                    (GoalType.reduction, "Reduktion"),
                    (GoalType.abstinence, "Abstinenz"),
                    (GoalType.observe, "Beobachten")
                ],
                selection: Binding(
                    get: { draft.goalType(for: substance) },
                    set: { draft.goalTypes[substance.name] = $0 }
                )
            )

            switch draft.goalType(for: substance) {
            case .reduction:
                Divider()
                    .overlay(Klar.borderSubtle)
                    .padding(.top, 14)

                KlarStepper(
                    label: "Limit / Monat",
                    value: Binding(
                        get: { draft.monthlyLimit(for: substance) },
                        set: { draft.monthlyLimits[substance.name] = $0 }
                    ),
                    range: 1...30
                )
                .padding(.top, 14)

            case .abstinence:
                Text("Abstinenz — jeder Eintrag wird trotzdem ohne Wertung erfasst.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.top, 12)

            case .observe:
                Text("Erstmal nur beobachten — kein Limit, kein Druck.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.top, 12)
            }
        }
    }
}

// MARK: - A4 · Ersatzhandlungen

struct SubstitutionStepView: View {
    let draft: OnboardingDraft
    let onFinish: () -> Void

    @State private var isAdding = false
    @State private var newAction = ""

    /// Offered as a starting point — the user can take them or write their own. Behavior
    /// Substitution only works if the alternative is *theirs*, so nothing is pre-selected.
    private let suggestions = ["Eine Runde rausgehen", "Jemanden anrufen", "Kalt duschen"]

    var body: some View {
        OnboardingScaffold(
            title: "Was hilft dir im Moment?",
            subtitle: "2–3 persönliche Alternativen. Im Craving ist keine Zeit, sie zu suchen — darum jetzt, in Ruhe.",
            step: 3,
            primaryTitle: "Fertig — App öffnen",
            onPrimary: onFinish
        ) {
            VStack(spacing: 10) {
                ForEach(Array(draft.substitutionActions.enumerated()), id: \.offset) { index, text in
                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 15))
                            .foregroundStyle(Klar.textTertiary)
                        Text(text)
                            .font(Klar.TypeScale.body)
                            .foregroundStyle(Klar.text)
                        Spacer()
                        Button {
                            draft.substitutionActions.remove(at: index)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Klar.textTertiary)
                        }
                        .accessibilityLabel("„\(text)“ entfernen")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(Klar.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous)
                            .strokeBorder(Klar.border, lineWidth: 1)
                    }
                }

                KlarDashedButton(title: "Weitere hinzufügen", tint: Klar.accentStrong) {
                    isAdding = true
                }

                if draft.substitutionActions.isEmpty {
                    KlarFlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                draft.substitutionActions.append(suggestion)
                            } label: {
                                KlarOutlineChip(text: suggestion)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
        .alert("Alternative hinzufügen", isPresented: $isAdding) {
            TextField("z. B. Jonas anrufen", text: $newAction)
            Button("Abbrechen", role: .cancel) { newAction = "" }
            Button("Hinzufügen") {
                let text = newAction.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { draft.substitutionActions.append(text) }
                newAction = ""
            }
        }
    }
}

// MARK: - Shared scaffold

/// The common frame of steps A2–A4: title, subtitle, scrollable body, primary button, dots.
struct OnboardingScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let step: Int
    let primaryTitle: LocalizedStringKey
    var isPrimaryEnabled: Bool = true
    let onPrimary: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Klar.TypeScale.display(26))
                    .foregroundStyle(Klar.text)
                    .padding(.bottom, 8)

                Text(subtitle)
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.bottom, 22)

                ScrollView {
                    content
                        .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)

                KlarPrimaryButton(
                    title: primaryTitle,
                    isEnabled: isPrimaryEnabled,
                    action: onPrimary
                )
                .padding(.vertical, 16)

                KlarStepDots(count: 4, current: step)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
    }
}
