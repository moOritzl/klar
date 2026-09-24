import SwiftUI
import SwiftData
import KlarCore

/// Problem solving (concept § 4, module E), reached from the card when the answer to „Bereust
/// du etwas?" is „ja". Three optional questions; the third comes back next to that substance's
/// pattern. It ends in a note, not in a plan, and nothing asks later whether it worked.
struct MorningReflectionView: View {
    let dayKey: String
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var trigger = ""
    @State private var wouldHaveHelped = ""
    @State private var nextTime = ""

    private var store: KlarStore { KlarStore(context: modelContext) }

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 15))
                        .foregroundStyle(Klar.Palette.cyan600)
                    KlarSectionLabel(text: "Kurz nachdenken")
                    Spacer()
                    Button("Später") { finish() }
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                }
                .padding(.bottom, 6)

                Text("Was war los?")
                    .font(Klar.TypeScale.display(24))
                    .foregroundStyle(Klar.text)
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 14) {
                        questionCard(number: 1, label: "Was war der Auslöser?", placeholder: "z. B. Gruppendruck, alle haben mitgemacht.", text: $trigger)
                        questionCard(number: 2, label: "Was hätte geholfen?", placeholder: "z. B. Früher gehen, bevor es kippt.", text: $wouldHaveHelped)
                        questionCard(number: 3, label: "Was machst du nächstes Mal anders?", placeholder: "Antwort tippen …", text: $nextTime)
                    }
                }
                .scrollIndicators(.hidden)

                KlarPrimaryButton(title: "Speichern") {
                    store.recordReflection(dayKey: dayKey, trigger: trigger, wouldHaveHelped: wouldHaveHelped, nextTime: nextTime)
                    finish()
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func questionCard(number: Int, label: LocalizedStringKey, placeholder: String, text: Binding<String>) -> some View {
        KlarCard(padding: 16) {
            HStack(spacing: 0) {
                Text("\(number) · ")
                    .font(Klar.TypeScale.caption)
                    .foregroundStyle(Klar.textTertiary)
                Text(label)
                    .font(Klar.TypeScale.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(Klar.textTertiary)
            }
            .padding(.bottom, 8)

            TextField(placeholder, text: text, axis: .vertical)
                .font(Klar.TypeScale.body)
                .foregroundStyle(Klar.text)
                .lineLimit(1...4)
        }
    }

    private func finish() {
        dismiss()
        onFinish()
    }
}
