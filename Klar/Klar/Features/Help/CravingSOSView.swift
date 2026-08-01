import SwiftUI
import SwiftData
import Combine

/// H2 · Craving-SOS.
///
/// No thinking required. The timer starts by itself, the user's own "Warum" and their own
/// alternatives are already on screen, and the one big button reaches a human. Everything here
/// was collected in calm moments (onboarding A4, settings) precisely because a craving is not a
/// moment for setup.
struct CravingSOSView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \SubstitutionAction.sortOrder) private var actions: [SubstitutionAction]

    /// Urge surfing: the standard 20 minutes. The point isn't the number, it's that the craving
    /// is framed as a wave that crests and passes.
    private static let duration: TimeInterval = 20 * 60

    @State private var deadline = Date().addingTimeInterval(duration)
    @State private var remaining: TimeInterval = duration
    @State private var isBreathing = false
    @State private var isEditingContact = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var store: KlarStore { KlarStore(context: modelContext) }
    private var whyNote: WhyNote? { store.latestWhyNote() }

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                Text("Dieses Gefühl geht vorbei. Du hast einen Plan.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                timerRing
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)

                KlarSectionLabel(text: "Dein „Warum“")
                    .padding(.bottom, 8)

                whyCard
                    .padding(.bottom, 16)

                KlarSectionLabel(text: "Stattdessen")
                    .padding(.bottom, 8)

                if actions.isEmpty {
                    Text("Noch keine Ersatzhandlungen hinterlegt. Du kannst sie unter Pläne → Ersatzhandlungen ergänzen.")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                } else {
                    KlarFlowLayout(spacing: 8) {
                        ForEach(actions) { action in
                            Text(action.text)
                                .font(Klar.TypeScale.caption)
                                .foregroundStyle(Klar.text)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Klar.surface, in: Capsule())
                                .overlay {
                                    Capsule().strokeBorder(Klar.border, lineWidth: 1)
                                }
                        }
                    }
                }

                Spacer()

                contactButton
                    .padding(.top, 20)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .fullScreenCover(isPresented: $isBreathing) {
            BreathingExerciseView()
        }
        .sheet(isPresented: $isEditingContact) {
            SupportContactSheet()
        }
        .onReceive(ticker) { _ in
            remaining = max(0, deadline.timeIntervalSinceNow)
        }
        .onChange(of: scenePhase) { _, phase in
            // The countdown is anchored to a wall-clock deadline, so it keeps running correctly
            // even if the user leaves the app to actually go for that walk.
            if phase == .active {
                remaining = max(0, deadline.timeIntervalSinceNow)
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Klar.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Klar.surfaceTint, in: Circle())
            }
            .accessibilityLabel("Schließen")
        }
        .padding(.bottom, 4)
    }

    private var timerRing: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Klar.accentTint)
                Circle()
                    .strokeBorder(Klar.accent.opacity(0.4), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Klar.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    Text(timeText)
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(Klar.text)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(remaining > 0 ? "URGE-SURFING" : "VORBEI")
                        .font(Klar.TypeScale.caption)
                        .tracking(0.6)
                        .foregroundStyle(Klar.accentStrong)
                }
            }
            .frame(width: 180, height: 180)

            Button {
                isBreathing = true
            } label: {
                Text("Atemübung starten")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Klar.text)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Klar.surface, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Klar.border, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var whyCard: some View {
        Group {
            if let whyNote, !whyNote.text.isEmpty {
                Text("„\(whyNote.text)“")
                    .font(Klar.TypeScale.bodySmall)
                    .italic()
                    .foregroundStyle(Klar.text)
            } else {
                Text("Noch kein „Warum“ hinterlegt. Du kannst es in den Einstellungen ergänzen. Es steht dann genau hier.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Klar.surface)
        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous)
                .strokeBorder(Klar.border, lineWidth: 1)
        }
    }

    private var contactButton: some View {
        Button {
            if let phone = settings.supportContactPhone,
               let url = URL(string: "tel://\(phone.filter(\.isNumber))") {
                openURL(url)
            } else {
                isEditingContact = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(contactButtonTitle)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Klar.accent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var contactButtonTitle: String {
        if let name = settings.supportContactName, !name.isEmpty {
            return "\(name) anrufen"
        }
        return "Vertrauensperson festlegen"
    }

    private var progress: CGFloat {
        CGFloat(1 - remaining / Self.duration)
    }

    private var timeText: String {
        let total = Int(remaining.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - Atemübung

/// Box breathing, 4-4-4-4. A single expanding circle and one word — nothing to read, nothing to
/// decide.
struct BreathingExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Phase: CaseIterable {
        case inhale, holdIn, exhale, holdOut

        var label: String {
            switch self {
            case .inhale: "Einatmen"
            case .holdIn: "Halten"
            case .exhale: "Ausatmen"
            case .holdOut: "Halten"
            }
        }

        var scale: CGFloat {
            switch self {
            case .inhale, .holdIn: 1.0
            case .exhale, .holdOut: 0.55
            }
        }

        var next: Phase {
            let all = Phase.allCases
            let index = all.firstIndex(of: self)!
            return all[(index + 1) % all.count]
        }
    }

    private static let phaseDuration: TimeInterval = 4

    @State private var phase: Phase = .inhale
    @State private var scale: CGFloat = 0.55

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Klar.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Klar.surfaceTint, in: Circle())
                    }
                    .accessibilityLabel("Schließen")
                }
                .padding(22)

                Spacer()

                ZStack {
                    Circle()
                        .fill(Klar.accentTint)
                        .frame(width: 240, height: 240)
                        .scaleEffect(scale)

                    Circle()
                        .strokeBorder(Klar.accent.opacity(0.5), lineWidth: 2)
                        .frame(width: 240, height: 240)
                        .scaleEffect(scale)

                    Text(phase.label)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Klar.text)
                        .contentTransition(.opacity)
                }

                Spacer()

                Text("Vier Sekunden ein, vier halten, vier aus, vier halten.")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                    .padding(.bottom, 40)
            }
        }
        .task {
            await runCycle()
        }
    }

    private func runCycle() async {
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: Self.phaseDuration)) {
                scale = phase.scale
            }
            try? await Task.sleep(for: .seconds(Self.phaseDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = phase.next
            }
        }
    }
}

// MARK: - Vertrauensperson

/// The one-tap call target. Stored in `UserDefaults`, never in the export — a phone number of
/// someone else is *their* data, and it has no business in the user's data dump.
struct SupportContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var name = ""
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Telefonnummer", text: $phone)
                        .keyboardType(.phonePad)
                } footer: {
                    Text("Wird nur auf diesem Gerät gespeichert und nicht exportiert. Im Craving-SOS genügt ein Tap.")
                }
            }
            .navigationTitle("Vertrauensperson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        settings.supportContactName = name.trimmingCharacters(in: .whitespaces)
                        settings.supportContactPhone = phone.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }
                }
            }
            .task {
                name = settings.supportContactName ?? ""
                phone = settings.supportContactPhone ?? ""
            }
        }
        .presentationDetents([.medium])
    }
}
