import SwiftUI

/// Ported 1:1 from the Claude Design project "Klar iOS App Design"
/// (`_ds/klar-design-system-.../tokens/*.css`). Names mirror the CSS custom
/// properties so a token change in the design file maps to exactly one change here.
///
/// The design is light-mode only ("Hell"), so these are literal values rather than
/// adaptive colors. `RootView` pins the color scheme accordingly.
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

    // MARK: - Semantic aliases

    static let bg = Color.white
    static let bgSubtle = Palette.teal25
    static let bgSunken = Palette.gray25
    static let bgInverse = Palette.teal900
    static let bgInverseDeep = Palette.teal950

    static let surface = Color.white
    static let surfaceTint = Palette.teal50

    static let border = Palette.teal200
    static let borderSubtle = Palette.teal100
    static let borderStrong = Palette.teal300

    static let text = Palette.teal950
    static let textSecondary = Palette.teal600
    static let textTertiary = Palette.teal500
    static let textOnInverse = Color.white
    static let textOnInverseSecondary = Palette.teal300

    static let accent = Palette.emerald500
    static let accentStrong = Palette.emerald700
    static let accentTint = Palette.emerald100

    static let link = Palette.cyan600

    static let danger = Palette.red600
    static let dangerTint = Palette.red100

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
    func klarShadow(_ shadow: (color: Color, radius: CGFloat, y: CGFloat)) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}
