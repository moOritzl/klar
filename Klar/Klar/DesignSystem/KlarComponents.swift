import SwiftUI

// MARK: - Card

/// The surface + radius-lg block that carries almost every group of content in the design.
///
/// It used to carry a 1px border as well. That was the CSS design file speaking: on the web a
/// card is outlined, on iOS it is a *fill* on a slightly darker page and never outlined. The
/// border was the single loudest "this was not built for iOS" signal in the app, so it is gone
/// and the separation now comes from `Klar.surface` sitting on `Klar.bgSubtle`.
///
/// The optional header slot is the Health/`insetGrouped` pattern: a label row, then a hairline
/// that runs the *full* width of the card while the content below stays inset.
struct KlarCard<Header: View, Content: View>: View {
    private let padding: CGFloat
    private let hasHeader: Bool
    private let header: Header
    private let content: Content

    init(
        padding: CGFloat = 18,
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) {
        self.init(padding: padding, hasHeader: true, content: content, header: header)
    }

    fileprivate init(
        padding: CGFloat,
        hasHeader: Bool,
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) {
        self.padding = padding
        self.hasHeader = hasHeader
        self.header = header()
        self.content = content()
    }

    /// The header keeps its own inset rather than inheriting `padding`, because a grouped card
    /// sets `padding: 0` so its rows can pad themselves — and a header flush against the card
    /// edge looks like a rendering fault.
    private var headerInset: CGFloat { max(padding, 18) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasHeader {
                header
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, headerInset)
                    .padding(.top, 14)
                    .padding(.bottom, 11)
                KlarRowDivider()
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
        }
        .background(Klar.surface)
        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
    }
}

extension KlarCard where Header == EmptyView {
    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.init(padding: padding, hasHeader: false, content: content, header: { EmptyView() })
    }
}

/// The hairline between rows of a grouped card. Full width under a card header, inset to the
/// content edge between sibling rows — the `List` separator convention.
struct KlarRowDivider: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Klar.borderSubtle)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

/// The dark "the app speaks" card — new month banner (B3), plan suggestion (G2).
struct KlarInverseCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(Klar.bgInverseDeep)
        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
    }
}

// MARK: - Buttons

/// Full-width emerald pill. The single primary action per screen.
struct KlarPrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Klar.Space.x2) {
                Text(title)
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? Klar.accent : Klar.borderStrong)
            .clipShape(Capsule())
        }
        .disabled(!isEnabled)
    }
}

/// Full-width white pill with a border — the "Nein" / secondary choice.
struct KlarSecondaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Klar.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Klar.surface)
                .clipShape(Capsule())
                .overlay { Capsule().strokeBorder(Klar.border, lineWidth: 1) }
        }
    }
}

/// The action that lives *inside* a card: a tinted capsule sized to its own content, not to the
/// screen. iOS reserves the full-width filled button for the one primary action of a sheet, and
/// uses this lighter form everywhere else — Health's "Fragebogen ausfüllen" and "Überprüfen".
struct KlarInlineButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var tint: Color = Klar.accentStrong
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(tint)
    }
}

/// Tinted pill with no border — "Fertig" / "Schließen" on the entry sheets.
struct KlarQuietButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Klar.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Klar.surfaceTint)
                .clipShape(Capsule())
        }
    }
}

/// Dashed "add another" affordance (A4, E2, G4, G5).
struct KlarDashedButton: View {
    let title: LocalizedStringKey
    var systemImage: String = "plus"
    var tint: Color = Klar.textSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Klar.Space.x2) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Klar.Radius.md, style: .continuous)
                    .strokeBorder(Klar.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
    }
}

/// Press feedback for anything where a whole card or row is the tap target.
///
/// `.buttonStyle(.plain)` was used for those, and it renders no press state at all — the card
/// simply sits there while the sheet appears, which is what made the app feel like a picture of
/// an app. iOS list rows *lighten*; they do not scale, so neither does this.
struct KlarRowButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = Klar.Radius.lg

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Klar.text.opacity(configuration.isPressed ? 0.06 : 0))
            }
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    /// The tap target is the whole card, so the shape has to be too — otherwise only the text
    /// inside it is hittable.
    func klarRowButtonStyle(cornerRadius: CGFloat = Klar.Radius.lg) -> some View {
        buttonStyle(KlarRowButtonStyle(cornerRadius: cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Chips & tags

/// Pill tag. Used for context tags, meta info, and as a selectable filter.
struct KlarChip: View {
    let text: String
    var isSelected: Bool = false
    var selectedColor: Color = Klar.Palette.cyan600
    var compact: Bool = false

    var body: some View {
        Text(text)
            .font(Klar.TypeScale.caption)
            .foregroundStyle(isSelected ? .white : Klar.textSecondary)
            .padding(.horizontal, compact ? 9 : 14)
            .padding(.vertical, compact ? 3 : 8)
            .background(isSelected ? selectedColor : Klar.surfaceTint)
            .clipShape(Capsule())
    }
}

/// Outlined variant used where chips sit on a tinted background (E3 filters, G3 tags).
struct KlarOutlineChip: View {
    let text: String
    var isSelected: Bool = false

    var body: some View {
        Text(text)
            .font(Klar.TypeScale.caption)
            .foregroundStyle(isSelected ? .white : Klar.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? Klar.Palette.cyan600 : Klar.surface)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule().strokeBorder(Klar.border, lineWidth: 1)
                }
            }
    }
}

// MARK: - Segmented control

/// The tinted-track segmented control (A3 goal type, E1 Kalender/Rückblick).
struct KlarSegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(Klar.TypeScale.caption)
                        .foregroundStyle(selection == option.value ? Klar.text : Klar.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selection == option.value {
                                Capsule()
                                    .fill(Klar.surface)
                                    .klarShadow(Klar.Shadow.sm)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Klar.surfaceTint)
        .clipShape(Capsule())
    }
}

// MARK: - Progress indicators

/// The quota bar: one segment per allowance, filled segments = *remaining*, not used.
/// This is the design's central inversion — "was bleibt, nicht was verbraucht wurde".
struct KlarQuotaBar: View {
    let limit: Int
    let remaining: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(limit, 0), id: \.self) { index in
                // Filled segments are drawn on the right, so the bar drains leftward
                // as the month is used up.
                let isRemaining = index >= (limit - max(remaining, 0))
                Capsule()
                    .fill(isRemaining ? Klar.accent : Color.clear)
                    .frame(height: 8)
                    .overlay {
                        if !isRemaining {
                            Capsule().strokeBorder(Klar.borderStrong, lineWidth: 1)
                        }
                    }
            }
        }
    }
}

/// Step dots for the onboarding pager (A1–A4).
struct KlarStepDots: View {
    let count: Int
    let current: Int
    var onInverse: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(fill(for: index))
                    .frame(width: index == current ? 22 : 6, height: 5)
            }
        }
    }

    private func fill(for index: Int) -> Color {
        if index == current {
            return onInverse ? .white : Klar.accent
        }
        return onInverse ? Color.white.opacity(0.28) : Klar.borderStrong
    }
}

/// The 3-segment progress rail at the top of the Weekly Review (F1–F3).
struct KlarProgressRail: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Klar.accent : Klar.borderStrong)
                    .frame(height: 4)
            }
        }
    }
}

/// Horizontal share bar used for the context distribution (E3).
struct KlarShareBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Klar.surfaceTint)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Text helpers

/// The uppercase tracking-wide eyebrow. Kept for labels *inside* a card, which is exactly where
/// iOS still uses this register — see Health's "SEELISCHES WOHLBEFINDEN" card header.
struct KlarSectionLabel: View {
    let text: LocalizedStringKey
    var color: Color = Klar.textTertiary

    var body: some View {
        Text(text)
            .font(Klar.TypeScale.caption)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// The header *above* a card, with an optional tinted text action on the right — Health's
/// "Angepinnt" / "Bearbeiten" pair.
///
/// The two registers are not interchangeable. Uppercase micro-grey inside a card reads as a
/// caption for the thing it sits on; outside a card it reads as a page that never quite starts.
/// So: sentence case, near body size, full text colour.
struct KlarGroupHeader<Trailing: View>: View {
    let text: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Klar.text)
            Spacer(minLength: 8)
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension KlarGroupHeader where Trailing == EmptyView {
    init(text: LocalizedStringKey) {
        self.init(text: text, trailing: { EmptyView() })
    }
}

/// The trailing action of a `KlarGroupHeader`. Plain tinted text, no chrome — iOS's
/// "Bearbeiten" affordance.
struct KlarHeaderAction: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Klar.link)
        }
    }
}

// `KlarScreenHeader` lived here: a title and a chevron in a tinted circle, drawn into the content
// because "the design has no UIKit navigation bar anywhere". Every screen that used it now has a
// real one, so it has no callers left. Deleted rather than kept around — a second way to draw a
// header is exactly how the app ended up with two header languages in one flow.

/// The persistent "log an entry" bar above the tab bar.
///
/// Replaces a floating circular `+` in the bottom-right corner. That was a Material Design
/// pattern — iOS has no such control anywhere, and it paid for its prominence by covering the
/// last row of whatever was underneath it. The accessory sits *beside* the content instead of on
/// top of it: iOS reserves the space, so nothing is ever hidden behind it.
///
/// Because it belongs to the `TabView` rather than to one screen, logging is now reachable from
/// all four tabs instead of only from Übersicht — which suits an app whose whole premise is that
/// the entry is the cheap part.
struct KlarLogEntryAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 19, weight: .semibold))
                Text("Eintrag erfassen")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Klar.accentStrong)
            .frame(maxWidth: .infinity)
            // Expanded is the state the bar takes over once the tab bar has shrunk away, so it
            // has the whole strip to itself and can afford the taller target.
            .padding(.vertical, placement == .expanded ? 14 : 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The trailing chevron that says "this opens something".
///
/// Used sparingly and on purpose: iOS puts one on every row that leads somewhere and on no row
/// that does not, which is what makes a list readable without touching it. A card that carries
/// this and does nothing is worse than a card with no chevron at all.
struct KlarDisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Klar.textTertiary)
            .accessibilityHidden(true)
    }
}

/// Small circular icon button (settings gear, inline edit pencil).
struct KlarIconButton: View {
    let systemImage: String
    var size: CGFloat = 32
    var accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(Klar.textSecondary)
                .frame(width: size, height: size)
                .background(Klar.surfaceTint, in: Circle())
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Stepper

/// The −/number/+ row used for monthly limits (A3, G4).
struct KlarStepper: View {
    let label: LocalizedStringKey
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...30

    var body: some View {
        HStack {
            Text(label)
                .font(Klar.TypeScale.bodySmall)
                .foregroundStyle(Klar.textSecondary)
            Spacer()
            HStack(spacing: 14) {
                stepButton("minus", enabled: value > range.lowerBound) {
                    value = max(range.lowerBound, value - 1)
                }
                Text("\(value)")
                    .font(Klar.TypeScale.numeral)
                    .foregroundStyle(Klar.text)
                    .frame(minWidth: 28)
                    .contentTransition(.numericText())
                stepButton("plus", enabled: value < range.upperBound) {
                    value = min(range.upperBound, value + 1)
                }
            }
        }
        // The system `Stepper` ticks on every increment; a hand-built one that stays silent
        // reads as unresponsive next to it.
        .sensoryFeedback(.selection, trigger: value)
    }

    private func stepButton(
        _ systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? Klar.textSecondary : Klar.borderStrong)
                .frame(width: 26, height: 26)
                .background(Klar.surfaceTint, in: Circle())
        }
        .disabled(!enabled)
        .accessibilityLabel(systemImage == "plus" ? "Erhöhen" : "Verringern")
    }
}

// MARK: - Flow layout

/// Wrapping row of chips. Used wherever the design has `flex-wrap: wrap` on tags.
struct KlarFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = layout(subviews: subviews, width: bounds.width)
        for row in rows {
            var x = bounds.minX
            for index in row.range {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var range: Range<Int>
        var y: CGFloat
        var height: CGFloat
        var width: CGFloat
    }

    private func layout(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var start = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append(Row(range: start..<index, y: y, height: rowHeight, width: x - spacing))
                start = index
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        if start < subviews.count {
            rows.append(
                Row(range: start..<subviews.count, y: y, height: rowHeight, width: max(x - spacing, 0))
            )
        }
        return rows
    }
}
