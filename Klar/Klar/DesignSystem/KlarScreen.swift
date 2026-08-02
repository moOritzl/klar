import SwiftUI

/// The common scaffold for the four tabs: background, padding, and a banner zone with enough
/// room above and below the title that it reads as a deliberate top of the screen rather than a
/// label stuck under the status bar.
///
/// An earlier version pushed the content block down into thumb reach with flexible space. It was
/// built, shipped to the user, and rejected on sight — a half-empty screen with the controls
/// hovering above the tab bar looked broken, whatever the ergonomics said. Content is top-aligned.
///
/// `scrollBounceBehavior(.basedOnSize)` is the other reason this exists: every tab used to
/// rubber-band vertically even when nothing could scroll.
struct KlarScreen<Banner: View, Content: View>: View {
    var horizontalPadding: CGFloat = 16
    @ViewBuilder var banner: Banner
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    banner
                        .padding(.bottom, Klar.Space.x5)

                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, Klar.Space.x4)
                .padding(.bottom, Klar.Space.x6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }
}

/// The banner headline. Bigger and more generously spaced than the old inline `Klar.TypeScale.title`
/// so the top of a screen reads as a deliberate zone rather than a label stuck to the status bar.
struct KlarScreenBanner<Detail: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var detail: Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Klar.TypeScale.display(30))
                .foregroundStyle(Klar.text)
                .padding(.bottom, Klar.Space.x4)

            detail
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension KlarScreenBanner where Detail == EmptyView {
    init(title: LocalizedStringKey) {
        self.init(title: title) { EmptyView() }
    }
}
