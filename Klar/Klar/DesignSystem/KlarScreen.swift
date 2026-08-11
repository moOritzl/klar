import SwiftUI

/// The common scaffold for the four tabs: background, padding, and the screen's title.
///
/// An earlier version pushed the content block down into thumb reach with flexible space. It was
/// built, shipped to the user, and rejected on sight — a half-empty screen with the controls
/// hovering above the tab bar looked broken, whatever the ergonomics said. Content is top-aligned.
///
/// The title used to be a `Text` in the scroll content, on the reasoning that the design had no
/// navigation bar anywhere. What that actually cost was every behaviour iOS attaches to a title:
/// it never collapsed, the bar never picked up the scroll-edge treatment, and nothing ever slid
/// *under* anything. So the title is now a real `navigationTitle` and the caller supplies the
/// `NavigationStack` — the caller, because three of the four tabs already had one for their own
/// links and nesting a second would break them.
///
/// **The bounce is deliberate.** This used to carry `scrollBounceBehavior(.basedOnSize)`, added
/// back when a short page rubber-banding over a static title looked like a glitch. With a real
/// large title that reading inverts: the give *is* the interaction. Dragging a short page is what
/// collapses the title into the bar and fades the content under it, exactly as Health does, and
/// `.basedOnSize` left those pages with no give at all — they read as frozen. So the default
/// bounce is back everywhere.
struct KlarScreen<Content: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var horizontalPadding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, Klar.Space.x2)
                .padding(.bottom, Klar.Space.x6)
        }
        // The background belongs to the scroll view, not to a `ZStack` wrapped around it: as a
        // sibling it forced the scroll view inside the safe area, and content that never travels
        // under the bar gives iOS nothing to apply the scroll-edge effect to.
        .background(Klar.bgSubtle)
        .navigationTitle(title)
        .navigationSubtitle(subtitle ?? "")
    }
}
