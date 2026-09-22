import SwiftUI

/// A section title with optional subtitle and trailing action.
///
/// Quieter than a screen `title` — a screen has one title and several sections.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(Typography.callout)
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            Spacer(minLength: 0)
            trailing
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

#Preview("SectionHeader") {
    VStack(alignment: .leading, spacing: Spacing.sectionGap) {
        SectionHeader("Career")
        SectionHeader("Recent form", subtitle: "Last five weeks")
        SectionHeader(title: "Leagues", subtitle: "3 active") {
            Text("See all")
                .font(Typography.caption)
                .foregroundStyle(Palette.accentInk)
        }
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity, alignment: .top)
    .gradientBackground()
}
