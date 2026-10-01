import SwiftUI
import SwiftData
import KlarCore

/// One substance on the Grenzen tab. Goes with the tab in the next commit.
struct GoalCard: View {
    let substance: Substance
    let store: KlarStore

    var body: some View {
        KlarCard(padding: 16) {
            Text(substance.name)
                .font(Klar.TypeScale.headline)
                .foregroundStyle(Klar.text)
                .padding(.bottom, 10)

            LimitEditor(substance: substance, store: store)

            Divider()
                .overlay(Klar.borderSubtle)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Toggle(isOn: Binding(
                get: { substance.asksMorningAfter },
                set: { store.setAsksMorningAfter($0, for: substance) }
            )) {
                Text("Morgen danach fragen")
                    .font(Klar.TypeScale.body)
                    .foregroundStyle(Klar.text)
            }
            .tint(Klar.accent)
        }
    }
}
