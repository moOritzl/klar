import SwiftUI

/// J2 · Panik-Ansicht — the façade. Reached by a two-finger double-tap anywhere in the app.
///
/// It has to survive being *handed to someone*, so it is a working calculator, not a picture of
/// one. There is no visible way back: the exit is a 1.5s long-press on the number display,
/// which a bystander will never find and the user only has to be told once.
struct PanicView: View {
    let onExit: () -> Void

    @State private var display = "0"
    @State private var accumulator: Double?
    @State private var pendingOperation: Operation?
    @State private var isAwaitingNewOperand = false

    private enum Operation: String {
        case add = "+", subtract = "−", multiply = "×", divide = "÷"
    }

    private enum Key: Hashable {
        case digit(Int)
        case operation(Operation)
        case clear, sign, percent, equals, decimal
    }

    private let rows: [[Key]] = [
        [.clear, .sign, .percent, .operation(.divide)],
        [.digit(7), .digit(8), .digit(9), .operation(.multiply)],
        [.digit(4), .digit(5), .digit(6), .operation(.subtract)],
        [.digit(1), .digit(2), .digit(3), .operation(.add)],
        [.digit(0), .decimal, .equals]
    ]

    var body: some View {
        ZStack {
            Color(hex: 0x0B0D0E).ignoresSafeArea()

            VStack(spacing: 12) {
                Spacer()

                Text(display)
                    .font(.system(size: 68, weight: .light))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 24)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1.5) { onExit() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Lange gedrückt halten, um Klar zu öffnen")

                VStack(spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { key in
                                keyButton(key)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
    }

    // MARK: - Keys

    @ViewBuilder
    private func keyButton(_ key: Key) -> some View {
        Button {
            press(key)
        } label: {
            GeometryReader { proxy in
                ZStack {
                    Capsule().fill(background(for: key))
                    Text(label(for: key))
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.white)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(height: keyHeight)
        }
        .buttonStyle(.plain)
        // The zero key is double-width, exactly like the system calculator.
        .frame(maxWidth: isWide(key) ? .infinity : nil)
        .frame(width: isWide(key) ? nil : keyHeight)
    }

    private var keyHeight: CGFloat {
        // 4 columns, 12pt gutters, 16pt outer padding.
        (UIScreen.main.bounds.width - 32 - 36) / 4
    }

    private func isWide(_ key: Key) -> Bool {
        if case .digit(0) = key { return true }
        return false
    }

    private func label(for key: Key) -> String {
        switch key {
        case .digit(let value): "\(value)"
        case .operation(let operation): operation.rawValue
        case .clear: display == "0" && accumulator == nil ? "AC" : "C"
        case .sign: "±"
        case .percent: "%"
        case .equals: "="
        case .decimal: ","
        }
    }

    private func background(for key: Key) -> Color {
        switch key {
        case .operation, .equals: Color(hex: 0xF79E1B)
        case .clear, .sign, .percent: Color(hex: 0x333537)
        default: Color(hex: 0x5A5C5E)
        }
    }

    // MARK: - Calculator

    private func press(_ key: Key) {
        switch key {
        case .digit(let value):
            appendDigit("\(value)")

        case .decimal:
            if isAwaitingNewOperand || display == "0" {
                display = "0,"
                isAwaitingNewOperand = false
            } else if !display.contains(",") {
                display += ","
            }

        case .clear:
            display = "0"
            if !isAwaitingNewOperand {
                accumulator = nil
                pendingOperation = nil
            }
            isAwaitingNewOperand = false

        case .sign:
            if display.hasPrefix("-") {
                display.removeFirst()
            } else if display != "0" {
                display = "-" + display
            }

        case .percent:
            setValue(currentValue / 100)

        case .operation(let operation):
            resolvePending()
            accumulator = currentValue
            pendingOperation = operation
            isAwaitingNewOperand = true

        case .equals:
            resolvePending()
            pendingOperation = nil
            accumulator = nil
            isAwaitingNewOperand = true
        }
    }

    private func appendDigit(_ digit: String) {
        if isAwaitingNewOperand || display == "0" {
            display = digit
            isAwaitingNewOperand = false
        } else {
            guard display.count < 12 else { return }
            display += digit
        }
    }

    private func resolvePending() {
        guard let pendingOperation, let accumulator else { return }
        let operand = currentValue
        let result: Double = switch pendingOperation {
        case .add: accumulator + operand
        case .subtract: accumulator - operand
        case .multiply: accumulator * operand
        case .divide: operand == 0 ? .nan : accumulator / operand
        }
        setValue(result)
        self.accumulator = result
    }

    private var currentValue: Double {
        Double(display.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func setValue(_ value: Double) {
        guard value.isFinite else {
            display = "Fehler"
            return
        }
        if value == value.rounded(), abs(value) < 1e12 {
            display = String(Int(value))
        } else {
            display = String(format: "%g", value).replacingOccurrences(of: ".", with: ",")
        }
    }
}

#Preview {
    PanicView {}
}
