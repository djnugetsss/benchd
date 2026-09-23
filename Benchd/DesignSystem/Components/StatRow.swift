import SwiftUI

/// A list row that ends in a number: an optional leading mark, a title, a quiet
/// subtitle, and a trailing value.
///
/// The profile is full of these — a draft pick and what it returned, a rival and
/// the record against them, a season and where it finished. They share one row so
/// the type sizes, the truncation and the vertical rhythm cannot drift apart from
/// each other three screens later.
///
/// The number on the right uses a display role, not body text: even at
/// `displaySmall` it stays the thing the eye lands on in the row, which is the
/// point — the label is the setup, the number is the payoff.
struct StatRow<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Spacing.sm) {
            leading

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.sm)

            trailing
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Convenience

extension StatRow where Trailing == StatRowValue {
    /// The common case: a leading mark and a trailing number.
    init(
        title: String,
        subtitle: String? = nil,
        value: String,
        valueCaption: String? = nil,
        @ViewBuilder leading: () -> Leading
    ) {
        self.init(title: title, subtitle: subtitle, leading: leading) {
            StatRowValue(value, caption: valueCaption)
        }
    }
}

extension StatRow where Leading == EmptyView {
    /// No leading mark, a custom trailing view.
    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: trailing)
    }
}

extension StatRow where Leading == EmptyView, Trailing == StatRowValue {
    /// The simplest form: a title, a subtitle, and a number.
    init(title: String, subtitle: String? = nil, value: String, valueCaption: String? = nil) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }) {
            StatRowValue(value, caption: valueCaption)
        }
    }
}

// MARK: - The trailing number

/// The right-hand side of a `StatRow`: a number with an optional caption under it.
///
/// A separate type rather than an inline `VStack` so a row's value is styled the
/// same everywhere, and so callers that need a pill or a glyph instead can pass
/// their own trailing view without restyling this one.
struct StatRowValue: View {
    let text: String
    var caption: String? = nil
    var style: DisplayStyle = .small
    /// Renders the number in `accentInk`. Spends accent budget — see DESIGN.md §3.
    var accented: Bool = false

    init(
        _ text: String,
        caption: String? = nil,
        style: DisplayStyle = .small,
        accented: Bool = false
    ) {
        self.text = text
        self.caption = caption
        self.style = style
        self.accented = accented
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            Text(text)
                .displayStyle(style)
                .foregroundStyle(accented ? Palette.accentInk : Palette.textPrimary)
                .lineLimit(1)

            if let caption {
                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview("StatRow") {
    VStack(spacing: Spacing.lg) {
        RowCard(data: PreviewRow.samples) { row in
            StatRow(
                title: row.title,
                subtitle: row.subtitle,
                value: row.value,
                valueCaption: row.caption
            ) {
                PillTag(row.position)
            }
        }

        Card {
            VStack(spacing: Spacing.md) {
                StatRow(title: "Dana Mode", subtitle: "14 meetings · since 2022", value: "12–2")
                SoftDivider()
                StatRow(title: "Dynasty Dads", subtitle: "9–5 · 124.8 a week") {
                    PillTag("Champion", tone: .accent)
                }
            }
        }
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity, alignment: .top)
    .gradientBackground()
}

/// Preview-only fixture.
private struct PreviewRow: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let value: String
    let caption: String
    let position: String

    static let samples = [
        PreviewRow(
            title: "Puka Nacua", subtitle: "9.01 · 2023 · Dynasty Dads",
            value: "308", caption: "+266 vs round", position: "WR"
        ),
        PreviewRow(
            title: "Jonathan Taylor", subtitle: "1.01 · 2023 · Dynasty Dads",
            value: "7", caption: "−371 vs round", position: "RB"
        ),
    ]
}
