import SwiftUI

/// What a `StatBlock` displays.
///
/// Numeric values count up on first appearance; text values (a record like
/// "128–74", a rank like "2nd") appear immediately, since sweeping a formatted
/// string is nonsense.
enum StatValue: Equatable {
    case number(Double, decimals: Int)
    case text(String)

    /// A whole number.
    static func number(_ value: Double) -> StatValue { .number(value, decimals: 0) }
    /// A whole number, from an integer.
    static func number(_ value: Int) -> StatValue { .number(Double(value), decimals: 0) }

    /// The value as it reads when fully settled — used for accessibility.
    var settledText: String {
        switch self {
        case .number(let value, let decimals):
            value.formatted(.number.precision(.fractionLength(decimals)))
        case .text(let string):
            string
        }
    }
}

/// A small uppercase label above a large number. **The most important component in
/// the app** — the stats are the emotional payload, so this is where the design
/// care concentrates.
///
/// The label sits above the number, not below: the eye should land on the number as
/// the payoff, not as the setup.
///
/// Numeric values sweep from zero over ~1.1s with an easeOut curve, once per
/// appearance. Reduce Motion skips straight to the final value.
struct StatBlock: View {
    let label: String
    let value: StatValue
    var style: DisplayStyle = .large
    /// Optional context beneath the number, e.g. "across 6 seasons".
    var caption: String? = nil
    /// Renders the number in `accentInk`. This spends accent budget — at most one
    /// accented stat per screen, and never more than two accents total.
    var accented: Bool = false
    var alignment: HorizontalAlignment = .leading

    @State private var displayed: Double = 0
    @State private var hasAnimated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: alignment, spacing: Spacing.xs) {
            Text(label)
                .statLabelStyle()

            numberView
                .displayStyle(style)
                .foregroundStyle(accented ? Palette.accentInk : Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let caption {
                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, Spacing.xxs)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var numberView: some View {
        switch value {
        case .number(let target, let decimals):
            CountingNumber(value: displayed, decimals: decimals)
                .onAppear { animate(to: target) }
        case .text(let string):
            Text(string)
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .center: .center
        case .trailing: .trailing
        default: .leading
        }
    }

    private var accessibilityValue: String {
        if let caption { "\(value.settledText), \(caption)" } else { value.settledText }
    }

    /// Runs once. Not on every scroll, not on every re-render.
    private func animate(to target: Double) {
        guard !hasAnimated else { return }
        hasAnimated = true

        guard !reduceMotion else {
            displayed = target
            return
        }
        withAnimation(Motion.countUp) { displayed = target }
    }
}

/// A `Text` whose numeric value SwiftUI can interpolate, which is what makes the
/// count-up possible — `animatableData` lets the animation system drive the number
/// through every intermediate value rather than cross-fading between two strings.
private struct CountingNumber: View, Animatable {
    var value: Double
    var decimals: Int

    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(value.formatted(.number.precision(.fractionLength(decimals))))
    }
}

#Preview("StatBlock — hero") {
    VStack(spacing: Spacing.sectionGap) {
        StatBlock(
            label: "All-time record",
            value: .text("128–74"),
            style: .hero,
            caption: "across 6 seasons",
            alignment: .center
        )
        StatBlock(
            label: "Championships",
            value: .number(3),
            style: .hero,
            alignment: .center
        )
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}

#Preview("StatBlock — row") {
    HStack(spacing: Spacing.md) {
        StatBlock(label: "Win %", value: .number(63.4, decimals: 1), style: .medium)
        StatBlock(label: "Titles", value: .number(3), style: .medium)
        StatBlock(label: "Playoffs", value: .number(5), style: .medium, accented: true)
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity)
    .gradientBackground()
}
