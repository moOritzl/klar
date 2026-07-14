import SwiftUI

// MARK: - Card

/// The surface + 1px border + radius-lg block that carries almost every group of
/// content in the design.
struct KlarCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(Klar.surface)
        .clipShape(RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Klar.Radius.lg, style: .continuous)
                .strokeBorder(Klar.border, lineWidth: 1)
        }
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

/// The uppercase tracking-wide eyebrow used above nearly every group.
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

/// Screen title + optional back chevron, matching the design's custom header
/// (the design has no UIKit navigation bar anywhere).
struct KlarScreenHeader<Trailing: View>: View {
    let title: String
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Klar.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Klar.surfaceTint, in: Circle())
                }
                .accessibilityLabel("Zurück")
            }
            Text(title)
                .font(Klar.TypeScale.title)
                .foregroundStyle(Klar.text)
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension KlarScreenHeader where Trailing == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
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
