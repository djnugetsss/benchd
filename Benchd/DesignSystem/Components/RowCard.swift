import SwiftUI

/// A card whose content is a list of rows, separated by hairlines that run the full
/// width of the card.
///
/// The separator belongs to the container, not the row: that is what keeps a list
/// from ending on a stray line, and it is why the card carries no padding of its own
/// and each row is inset instead.
///
/// Rows are inset `cardPadding` horizontally so they line up with every other card
/// on the screen, and `md` vertically — less than a card's own padding, because a
/// list of eight seasons at full card padding scrolls like a wall.
///
/// This is deliberately not a `List`. `List` brings its own background, insets,
/// separator colour and scrolling, all of which would have to be fought.
struct RowCard<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
    let data: Data
    var radius: CGFloat = Radius.card
    var elevation: Elevation = .soft
    @ViewBuilder var row: (Data.Element) -> Row

    var body: some View {
        Card(padding: 0, radius: radius, elevation: elevation) {
            VStack(spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
                    if index > 0 { SoftDivider() }

                    row(element)
                        .padding(.horizontal, Spacing.cardPadding)
                        .padding(.vertical, Spacing.md)
                }
            }
        }
    }
}

#Preview("RowCard") {
    VStack(spacing: Spacing.lg) {
        RowCard(data: PreviewSeason.samples) { season in
            StatRow(title: season.league, subtitle: season.record, value: season.finish) {
                Text(String(season.year))
                    .displayStyle(.small)
                    .foregroundStyle(Palette.textSecondary)
            }
        }

        // A single row still reads as a card, with no stray separator.
        RowCard(data: Array(PreviewSeason.samples.prefix(1))) { season in
            StatRow(title: season.league, subtitle: season.record, value: season.finish)
        }
    }
    .padding(Spacing.screen)
    .frame(maxHeight: .infinity, alignment: .top)
    .gradientBackground()
}

/// Preview-only fixture.
private struct PreviewSeason: Identifiable {
    let id = UUID()
    let year: Int
    let league: String
    let record: String
    let finish: String

    static let samples = [
        PreviewSeason(year: 2026, league: "Dynasty Dads", record: "4–0 · 133.3 a week", finish: "—"),
        PreviewSeason(year: 2023, league: "Dynasty Dads", record: "9–5 · 124.8 a week", finish: "1st"),
        PreviewSeason(year: 2022, league: "Work League", record: "20–8 · 111.4 a week", finish: "5th"),
    ]
}
