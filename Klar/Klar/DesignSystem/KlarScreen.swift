import SwiftUI

/// The layout rule for the four tabs: what you look at sits at the top, what you touch sits at
/// the bottom.
///
/// The banner is anchored under the status bar with real breathing room; the content block is
/// pushed toward the tab bar by flexible space. When the content outgrows the viewport the
/// flexible space collapses to `Klar.Space.x6` and the screen scrolls like any other. That is
/// why the inner frame uses `minHeight` and not `containerRelativeFrame` — an exact height would
/// clip a long month or a full plan list.
struct KlarScreen<Banner: View, Content: View>: View {
    var horizontalPadding: CGFloat = 16
    @ViewBuilder var banner: Banner
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Klar.bgSubtle.ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        banner

                        Spacer(minLength: Klar.Space.x6)

                        content
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: proxy.size.height - Klar.Space.x6 * 2,
                        alignment: .leading
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, Klar.Space.x6)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
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
