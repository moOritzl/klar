import SwiftUI
import UIKit

/// Ported 1:1 from the Claude Design project "Klar iOS App Design"
/// (`_ds/klar-design-system-.../tokens/*.css`). Names mirror the CSS custom
/// properties so a token change in the design file maps to exactly one change here.
///
/// The design file ships light only; the dark values are derived from the same teal ramp read
/// from the other end, so both schemes stay one family. `RootView` applies the user's choice.
enum Klar {

    // MARK: - Base palette (tokens/colors.css)

    enum Palette {
        static let teal950 = Color(hex: 0x15272B)
        static let teal900 = Color(hex: 0x0E3B43)
        static let teal800 = Color(hex: 0x17444C)
        static let teal700 = Color(hex: 0x28545C)
        static let teal600 = Color(hex: 0x44585E)
        static let teal500 = Color(hex: 0x5C7078)
        static let teal400 = Color(hex: 0x8FB2AE)
        static let teal300 = Color(hex: 0xBFD8D4)
        static let teal200 = Color(hex: 0xD5E4E2)
        static let teal100 = Color(hex: 0xE6F2F0)
        static let teal50 = Color(hex: 0xEEF6F5)
        static let teal25 = Color(hex: 0xF7FAFA)
        static let gray25 = Color(hex: 0xF4F6F6)

        static let emerald700 = Color(hex: 0x1A6B62)
        static let emerald600 = Color(hex: 0x02A488)
        static let emerald500 = Color(hex: 0x02C39A)
        static let emerald100 = Color(hex: 0xD9F2EB)

        static let cyan600 = Color(hex: 0x028090)

        static let red600 = Color(hex: 0xC0392B)
        static let red100 = Color(hex: 0xFBECEA)
    }

    /// Resolves per trait collection rather than per asset catalog entry: the 25 semantic tokens
    /// below stay one line each, which is what keeps them mappable 1:1 onto the design file's CSS
    /// custom properties.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

    // MARK: - Semantic aliases

    static let bg = adaptive(light: 0xFFFFFF, dark: 0x0E1719)
    static let bgSubtle = adaptive(light: 0xF7FAFA, dark: 0x15272B)
    static let bgSunken = adaptive(light: 0xF4F6F6, dark: 0x0E1719)
    /// The inverse surfaces are the app's emphasis block: in light they are the darkest thing on
    /// a near-white page. Mirroring that literally in dark mode (a near-black card on a dark page)
    /// measured 1.15:1 and read as the *quietest* element, inverting the role. So in dark they
    /// step up out of the page instead of down into it, keeping "most emphatic" intact.
    static let bgInverse = adaptive(light: 0x0E3B43, dark: 0x2C7A82)
    static let bgInverseDeep = adaptive(light: 0x15272B, dark: 0x24686F)

    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1B3238)
    static let surfaceTint = adaptive(light: 0xEEF6F5, dark: 0x17444C)

    static let border = adaptive(light: 0xD5E4E2, dark: 0x28545C)
    static let borderSubtle = adaptive(light: 0xE6F2F0, dark: 0x1F4048)
    static let borderStrong = adaptive(light: 0xBFD8D4, dark: 0x44585E)

    static let text = adaptive(light: 0x15272B, dark: 0xEEF6F5)
    static let textSecondary = adaptive(light: 0x44585E, dark: 0xBFD8D4)
    static let textTertiary = adaptive(light: 0x5C7078, dark: 0x8FB2AE)
    /// Always on a filled accent or inverse surface, so it does not flip.
    static let textOnInverse = Color.white
    static let textOnInverseSecondary = Palette.teal300

    static let accent = adaptive(light: 0x02C39A, dark: 0x02C39A)
    static let accentStrong = adaptive(light: 0x1A6B62, dark: 0x02C39A)
    static let accentTint = adaptive(light: 0xD9F2EB, dark: 0x123B37)

    static let link = adaptive(light: 0x028090, dark: 0x40B4C4)

    static let danger = adaptive(light: 0xC0392B, dark: 0xE8705F)
    static let dangerTint = adaptive(light: 0xFBECEA, dark: 0x3A1C18)

    // MARK: - Radii (tokens/spacing.css)

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        /// `--radius-pill`. Large enough to fully round any control we ship.
        static let pill: CGFloat = 999
    }

    // MARK: - Spacing (4px base grid)

    enum Space {
        static let x1: CGFloat = 4
        static let x2: CGFloat = 8
        static let x3: CGFloat = 12
        static let x4: CGFloat = 16
        static let x5: CGFloat = 20
        static let x6: CGFloat = 24
        static let x8: CGFloat = 32
        static let x10: CGFloat = 40
        static let x12: CGFloat = 48
    }

    // MARK: - Type scale (tokens/typography.css)
    //
    // `--font-ui` is the system font (SF Pro) and `--font-display` is an editorial
    // serif. On iOS we get both for free via `Font.system(design:)`, so no font files
    // are bundled.

    enum TypeScale {
        // UI register
        static let title = Font.system(size: 22, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let bodySmall = Font.system(size: 14, weight: .regular)
        static let caption = Font.system(size: 12, weight: .medium)
        static let numeral = Font.system(size: 28, weight: .semibold)

        // Display register (serif)
        static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .serif)
        }

        static let displaySm = display(24)
        static let displayMd = display(26)
        static let displayLg = display(30)
    }

    // MARK: - Shadows

    enum Shadow {
        /// `--shadow-sm: 0 1px 2px rgba(14, 59, 67, 0.06)`
        static let sm = (color: Palette.teal900.opacity(0.06), radius: CGFloat(2), y: CGFloat(1))
        /// `--shadow-md: 0 4px 16px rgba(14, 59, 67, 0.08)`
        static let md = (color: Palette.teal900.opacity(0.08), radius: CGFloat(8), y: CGFloat(4))
        /// `--shadow-lg: 0 12px 32px rgba(14, 59, 67, 0.12)`
        static let lg = (color: Palette.teal900.opacity(0.12), radius: CGFloat(16), y: CGFloat(12))
    }

    // MARK: - Substance dot colors
    //
    // `Substance.colorIndex` maps into this ring. The design uses teal-700 / cyan-600 /
    // teal-400 / text-tertiary as the entry-dot colors; keeping them in one ordered list
    // means a substance's color is stable across Today, History and the entry sheet.

    static let substanceColors: [Color] = [
        Palette.teal700,
        Palette.cyan600,
        Palette.teal400,
        Palette.emerald600,
        Palette.teal500,
        Palette.emerald700,
        Palette.teal800,
        Palette.teal300
    ]

    static func substanceColor(_ index: Int) -> Color {
        substanceColors[abs(index) % substanceColors.count]
    }
}

// MARK: - Helpers

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension View {
    /// In dark mode a translucent dark shadow does nothing. Elevation there comes from the
    /// surface being lighter than its background, so the shadow simply drops out.
    func klarShadow(_ shadow: (color: Color, radius: CGFloat, y: CGFloat)) -> some View {
        modifier(KlarShadowModifier(shadow: shadow))
    }
}

private struct KlarShadowModifier: ViewModifier {
    let shadow: (color: Color, radius: CGFloat, y: CGFloat)
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(
            color: colorScheme == .dark ? .clear : shadow.color,
            radius: shadow.radius,
            x: 0,
            y: shadow.y
        )
    }
}
