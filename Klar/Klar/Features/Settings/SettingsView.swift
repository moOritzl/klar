import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// I1 · Einstellungen.
///
/// Reached from the gear on „Heute", never a tab. A deliberately boring place: everything you
/// decide once and then forget, kept away from the four tabs. Privacy comes first on the screen
/// because it comes first in the product.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @State private var isEditingWhy = false
    @State private var isEditingContact = false
    @State private var isManagingSubstances = false
    @State private var isShowingDataScreen = false
    @State private var lockUnavailable = false

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        KlarGroupHeader(text: "Privatsphäre & Sicherheit")
                            .padding(.bottom, 8)

                        SettingsGroup {
                            SettingsToggleRow(
                                icon: "faceid",
                                title: "Face ID Sperre",
                                isOn: Binding(
                                    get: { settings.isAppLockEnabled },
                                    set: { enableLock($0) }
                                )
                            )

                            KlarRowDivider()

                            SettingsPickerRow(
                                icon: "timer",
                                title: "Auto-Sperre",
                                options: AutoLockDelay.allCases,
                                label: \.label,
                                selection: $settings.autoLockDelay
                            )
                        }
                        .padding(.bottom, 16)

                        KlarGroupHeader(text: "Darstellung")
                            .padding(.bottom, 8)

                        SettingsGroup {
                            SettingsPickerRow(
                                icon: "circle.lefthalf.filled",
                                title: "Erscheinungsbild",
                                options: AppAppearance.allCases,
                                label: \.label,
                                selection: $settings.appearance
                            )
                        }
                        .padding(.bottom, 16)

                        KlarGroupHeader(text: "Tag")
                            .padding(.bottom, 8)

                        // Read-only on purpose. The boundary decides how every derived number is
                        // bucketed, and changing it would re-bucket entries that are already
                        // logged — so it is stated here, not offered as a setting.
                        SettingsGroup {
                            SettingsInfoRow(
                                icon: "clock",
                                title: "Ein Tag läuft von 5 Uhr bis 5 Uhr",
                                subtitle: "Ein Eintrag um 2 Uhr zählt zum Vortag."
                            )
                        }
                        .padding(.bottom, 16)

                        KlarGroupHeader(text: "Deine Daten")
                            .padding(.bottom, 8)

                        SettingsGroup {
                            SettingsNavigationRow(
                                icon: "list.bullet",
                                title: "Substanzen & Kosten"
                            ) { isManagingSubstances = true }

                            KlarRowDivider()

                            SettingsNavigationRow(
                                icon: "quote.opening",
                                title: "Dein „Warum“",
                                subtitle: whySubtitle
                            ) { isEditingWhy = true }

                            KlarRowDivider()

                            SettingsNavigationRow(
                                icon: "person.crop.circle",
                                title: "Vertrauensperson",
                                subtitle: settings.supportContactName ?? "Für den Ein-Tap-Anruf im SOS"
                            ) { isEditingContact = true }

                            KlarRowDivider()

                            SettingsToggleRow(
                                icon: "bell",
                                title: "Benachrichtigungen",
                                subtitle: "Generische Texte, nie Substanznamen",
                                isOn: Binding(
                                    get: { settings.areNotificationsEnabled },
                                    set: { enableNotifications($0) }
                                )
                            )

                            KlarRowDivider()

                            SettingsNavigationRow(
                                icon: "square.and.arrow.down",
                                title: "Daten"
                            ) { isShowingDataScreen = true }
                        }
                        .padding(.bottom, 16)

                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 15))
                                .foregroundStyle(Klar.accentStrong)
                            Text("Local-first. Kein Account, kein Server, nichts zu kompromittieren.")
                                .font(Klar.TypeScale.bodySmall)
                                .foregroundStyle(Klar.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Klar.surfaceTint)
                        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, Klar.Space.x2)
                    .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Klar.bgSubtle)
            // The title was a `Text` in the content while an empty inline bar sat above it — the
            // screen had a navigation bar and used none of it. One title, in the bar.
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isEditingWhy) { WhyNoteSheet() }
        .sheet(isPresented: $isEditingContact) { SupportContactSheet() }
        .sheet(isPresented: $isManagingSubstances) { SubstancesView() }
        .sheet(isPresented: $isShowingDataScreen) { DataManagementView() }
        .alert("Face ID nicht verfügbar", isPresented: $lockUnavailable) {
            Button("Verstanden", role: .cancel) {}
        } message: {
            Text("Auf diesem Gerät ist weder Face ID noch ein Gerätecode eingerichtet. Ohne einen davon kann Klar nicht sperren.")
        }
    }

    private var whySubtitle: String {
        store.latestWhyNote()?.text ?? "Erscheint im Craving-SOS"
    }

    /// Never leave the switch on when the device can't actually honour it.
    private func enableLock(_ isOn: Bool) {
        guard isOn else {
            settings.isAppLockEnabled = false
            return
        }
        guard AppLockManager.canAuthenticate() else {
            lockUnavailable = true
            return
        }
        settings.isAppLockEnabled = true
    }

    private func enableNotifications(_ isOn: Bool) {
        guard isOn else {
            settings.areNotificationsEnabled = false
            NotificationScheduler.cancelAll()
            return
        }
        Task {
            let granted = await NotificationScheduler.requestAuthorization()
            settings.areNotificationsEnabled = granted
            if granted {
                await NotificationScheduler.scheduleWeeklyReviewReminder()
            }
        }
    }
}

// MARK: - Rows

/// Rows in one card, hairlines between them. This used to carry its own copy of the card chrome
/// — surface, radius, border — which meant `KlarCard` and this had to be kept in sync by hand.
/// It is now the same `KlarCard`, just without the padding, because the rows pad themselves.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        KlarCard(padding: 0) {
            content
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Klar.textSecondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
                if let subtitle {
                    Text(subtitle)
                        .font(Klar.TypeScale.caption)
                        .foregroundStyle(Klar.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Klar.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

struct SettingsPickerRow<Value: Hashable & Identifiable>: View {
    let icon: String
    let title: LocalizedStringKey
    let options: [Value]
    let label: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Klar.textSecondary)
                .frame(width: 18)
            Text(title)
                .font(Klar.TypeScale.body)
                .foregroundStyle(Klar.text)
            Spacer()
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(label(option)).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Klar.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// A row that states a rule instead of offering a control. Same anatomy as the interactive rows so
/// it reads as part of the list, with no tap target and no chevron to promise one.
struct SettingsInfoRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Klar.textSecondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
                Text(subtitle)
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsNavigationRow: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Klar.textSecondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Klar.TypeScale.body)
                        .foregroundStyle(Klar.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(Klar.TypeScale.caption)
                            .foregroundStyle(Klar.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Klar.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - „Warum"

struct WhyNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text = ""

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("z. B. Ich will die Wochenenden wieder klar erleben.", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                } footer: {
                    Text("Erscheint im Craving-SOS.")
                }
            }
            .navigationTitle("Dein „Warum“")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { store.setWhyNote(trimmed) }
                        dismiss()
                    }
                }
            }
            .task {
                text = store.latestWhyNote()?.text ?? ""
            }
        }
        .presentationDetents([.medium])
    }
}
