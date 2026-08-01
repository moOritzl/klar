import SwiftUI
import SwiftData

/// H1 · Tab „Hilfe".
///
/// Must be operable one-handed in a bad moment, which is why the whole block sits in the lower
/// half of the screen: SOS first, reference material last. A permanently visible tab normalizes
/// asking for help — it's a basic function of the app, not an emergency exit.
struct HelpView: View {
    @State private var isSOSPresented = false

    var body: some View {
        NavigationStack {
            KlarScreen {
                KlarScreenBanner(title: "Hilfe")
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    sosButton
                        .padding(.bottom, 16)

                    VStack(spacing: 10) {
                        NavigationLink {
                            EmergencyView()
                        } label: {
                            emergencyRow
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("help.emergency")

                        NavigationLink {
                            CounselingView()
                        } label: {
                            helpRow(
                                icon: "person.2",
                                title: "Beratung",
                                subtitle: "Suchtberatung · Hotlines · anonym"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("help.counseling")

                        NavigationLink {
                            RiskInfoListView()
                        } label: {
                            helpRow(
                                icon: "book",
                                title: "Risiko-Infos",
                                subtitle: "Nachschlagewerk, kein Startpunkt"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("help.riskInfo")
                    }
                }
            }
            .fullScreenCover(isPresented: $isSOSPresented) {
                CravingSOSView()
            }
        }
    }

    private var sosButton: some View {
        Button {
            isSOSPresented = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.22), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Craving-SOS")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Ein Tap — die App führt dich.")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(Klar.accent)
            .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
            .klarShadow(Klar.Shadow.md)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("help.sos")
        .accessibilityLabel("Craving-SOS. Ein Tap — die App führt dich.")
    }

    /// The only place in the app that uses red — and it means "call an ambulance", not
    /// "you did badly".
    private var emergencyRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18))
                .foregroundStyle(Klar.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notfall")
                    .font(Klar.TypeScale.body.weight(.semibold))
                    .foregroundStyle(Klar.danger)
                Text("Warnzeichen · Erste Hilfe · 112")
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.danger.opacity(0.8))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Klar.danger)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Klar.dangerTint)
        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous)
                .strokeBorder(Klar.danger, lineWidth: 1)
        }
    }

    private func helpRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Klar.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Klar.TypeScale.body.weight(.semibold))
                    .foregroundStyle(Klar.text)
                Text(subtitle)
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Klar.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Klar.surface)
        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous)
                .strokeBorder(Klar.border, lineWidth: 1)
        }
    }
}

// MARK: - H3 · Notfall

struct EmergencyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Notfall")
                        .font(Klar.TypeScale.title)
                        .foregroundStyle(Klar.text)
                        .padding(.bottom, 16)

                    Button {
                        call(EmergencyContent.emergencyNumber)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                            Text("Notruf 112 anrufen")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity)
                        .background(Klar.danger)
                        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
                        .klarShadow(Klar.Shadow.md)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 18)

                    KlarSectionLabel(text: "Warnzeichen erkennen")
                        .padding(.bottom, 8)

                    KlarCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(EmergencyContent.warningSigns, id: \.self) { sign in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(Klar.danger)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 7)
                                    Text(sign)
                                        .font(Klar.TypeScale.bodySmall)
                                        .foregroundStyle(Klar.text)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    KlarSectionLabel(text: "Erste-Hilfe-Schritte")
                        .padding(.bottom, 8)

                    KlarCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(EmergencyContent.firstAidSteps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Klar.textSecondary)
                                        .frame(width: 22, height: 22)
                                        .background(Klar.surfaceTint, in: Circle())
                                    Text(step)
                                        .font(Klar.TypeScale.bodySmall)
                                        .foregroundStyle(Klar.text)
                                        .padding(.top, 2)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 12)

                    Text("Notruf hilft, ohne die Polizei zu rufen. Sag ehrlich, was konsumiert wurde — das entscheidet über die richtige Behandlung.")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func call(_ number: String) {
        guard let url = URL(string: "tel://\(number.filter(\.isNumber))") else { return }
        openURL(url)
    }
}

// MARK: - H4 · Beratung

struct CounselingView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Beratung")
                        .font(Klar.TypeScale.title)
                        .foregroundStyle(Klar.text)
                        .padding(.bottom, 16)

                    KlarSectionLabel(text: "Bundesweit · anonym")
                        .padding(.bottom, 8)

                    VStack(spacing: 10) {
                        ForEach(CounselingDirectory.national) { offer in
                            offerCard(offer)
                        }
                    }
                    .padding(.bottom, 18)

                    KlarSectionLabel(text: "Vor Ort")
                        .padding(.bottom, 8)

                    Button {
                        openURL(CounselingDirectory.localDirectoryURL)
                    } label: {
                        KlarCard(padding: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Suchthilfeverzeichnis der DHS")
                                        .font(Klar.TypeScale.headline)
                                        .foregroundStyle(Klar.text)
                                    Text("Beratungsstellen in deiner Stadt — offiziell gepflegt, laufend aktuell.")
                                        .font(Klar.TypeScale.bodySmall)
                                        .foregroundStyle(Klar.textTertiary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Klar.link)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)

                    Text("Der Weg zu Menschen ist immer einen Tap entfernt.")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func offerCard(_ offer: CounselingOffer) -> some View {
        Button {
            if let phone = offer.phone,
               let url = URL(string: "tel://\(phone.filter(\.isNumber))") {
                openURL(url)
            } else if let url = offer.url {
                openURL(url)
            }
        } label: {
            KlarCard(padding: 16) {
                HStack {
                    Text(offer.name)
                        .font(Klar.TypeScale.headline)
                        .foregroundStyle(Klar.text)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: offer.phone != nil ? "phone.fill" : "chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(offer.phone != nil ? Klar.accentStrong : Klar.textTertiary)
                }
                .padding(.bottom, 6)

                KlarFlowLayout(spacing: 6) {
                    ForEach(offer.badges, id: \.self) { badge in
                        Text(badge.label)
                            .font(Klar.TypeScale.caption)
                            .foregroundStyle(badge.isEmphasized ? Klar.accentStrong : Klar.textTertiary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(badge.isEmphasized ? Klar.accentTint : Klar.surfaceTint, in: Capsule())
                    }
                }

                if let note = offer.note {
                    Text(note)
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - H5 · Risiko-Infos

struct RiskInfoListView: View {
    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Risiko-Infos")
                        .font(Klar.TypeScale.title)
                        .foregroundStyle(Klar.text)
                        .padding(.bottom, 4)

                    Text("Gefahrenvermeidung mit Quellen. Keine Dosisempfehlungen, keine Wirkoptimierung.")
                        .font(Klar.TypeScale.bodySmall)
                        .foregroundStyle(Klar.textTertiary)
                        .padding(.bottom, 18)

                    VStack(spacing: 10) {
                        ForEach(RiskInfoLibrary.entries) { info in
                            NavigationLink {
                                RiskInfoDetailView(info: info)
                            } label: {
                                KlarCard(padding: 16) {
                                    HStack {
                                        Text(info.substanceName)
                                            .font(Klar.TypeScale.headline)
                                            .foregroundStyle(Klar.text)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Klar.textTertiary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RiskInfoDetailView: View {
    let info: RiskInfo

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(info.substanceName)
                        .font(Klar.TypeScale.title)
                        .foregroundStyle(Klar.text)
                        .padding(.bottom, 16)

                    KlarCard(padding: 16) {
                        KlarSectionLabel(text: "Gefahren")
                            .padding(.bottom, 8)
                        Text(info.dangers)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.text)
                            .lineSpacing(3)
                    }
                    .padding(.bottom, 12)

                    KlarCard(padding: 16) {
                        KlarSectionLabel(text: "Zu vermeidende Kombinationen", color: Klar.danger)
                            .padding(.bottom, 8)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(info.avoidCombinations, id: \.self) { combination in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Klar.danger)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 7)
                                    Text(combination)
                                        .font(Klar.TypeScale.bodySmall)
                                        .foregroundStyle(Klar.text)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 12)

                    KlarCard(padding: 16) {
                        KlarSectionLabel(text: "Notfallsymptome")
                            .padding(.bottom, 8)
                        Text(info.emergencySymptoms)
                            .font(Klar.TypeScale.bodySmall)
                            .foregroundStyle(Klar.text)
                            .lineSpacing(3)
                    }
                    .padding(.bottom, 14)

                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 12))
                        Text("Quelle: \(info.source)")
                    }
                    .font(Klar.TypeScale.bodySmall)
                    .foregroundStyle(Klar.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
