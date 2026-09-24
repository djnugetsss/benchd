import SwiftUI

/// The shareable weekly wrap card.
///
/// This is the surface the whole app is judged on: it is the only thing that
/// leaves Benchd and lands in a feed next to everyone else's fantasy graphics,
/// which are — without exception — dark, saturated, and covered in team logos.
/// The entire bet here is that the calm one is the one people are proud to post.
///
/// Rules this card holds itself to, beyond `DESIGN.md`:
///
/// - **It is laid out at a fixed size** (`WrapFormat.size`), never against the
///   screen. The exported PNG is then pixel-identical to the preview, and a
///   layout that is right on one phone cannot be wrong on another.
/// - **Square corners.** The rounding belongs to the app's presentation of the
///   card; an exported image with rounded corners carries transparent wedges
///   that turn black the moment Instagram flattens it.
/// - **No pixel is decoration.** Every mark is a number, a label for a number,
///   or the wordmark.
struct WrapCardView: View {
    let wrap: WeeklyWrap
    var style: WrapCardStyle = .scoreline
    var format: WrapFormat = .story

    var body: some View {
        Group {
            switch style {
            case .scoreline: scoreline
            case .podium: podium
            case .cover: cover
            }
        }
        .padding(format.padding)
        .frame(width: format.size.width, height: format.size.height)
        // The bloom is the one piece of brand atmosphere on the card — a single
        // hue at 14%, which reads as light rather than as a gradient.
        .background(GradientBackground(showsBloom: true))
        .clipped()
        .environment(\.colorScheme, .light)
    }

    private var performers: [WrapPerformer] { Array(wrap.performers.prefix(3)) }

    // MARK: - Scoreline
    //
    // Hero-number led. The week's score is the focal point; the lineup that
    // produced it sits underneath, and the story of the week signs off at the
    // bottom. The most informative of the three, and the most conventional.

    private var scoreline: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text(wrap.weekText).statLabelStyle()
                Spacer(minLength: Spacing.xs)
                Text(String(wrap.season)).statLabelStyle()
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(wrap.pointsLabel).statLabelStyle()

                Text(wrap.pointsFor.wrapPoints)
                    .displayStyle(.hero)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(wrap.resultLine)
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                SoftDivider()

                Text("Top performers")
                    .statLabelStyle()
                    .padding(.top, Spacing.xxs)

                ForEach(performers) { performer in
                    HStack(spacing: Spacing.sm) {
                        PillTag(performer.position ?? "FLEX")

                        Text(performer.name)
                            .font(Typography.body)
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Spacer(minLength: Spacing.xs)

                        Text(performer.points.wrapPoints)
                            .displayStyle(.small)
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
            }

            Spacer(minLength: Spacing.xs)

            HStack(alignment: .bottom) {
                highlightBlock
                Spacer(minLength: Spacing.md)
                Wordmark(tone: .solid)
            }
        }
    }

    // MARK: - Podium
    //
    // List led. The three numbers run down the left edge as a spine, largest
    // first, and the card is read as a ranking rather than as a scoreboard.
    // The week's own score is demoted to the masthead, where it belongs when
    // the players are the subject.

    private var podium: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text(wrap.weekText).statLabelStyle()
                Spacer(minLength: Spacing.xs)
                Text("\(wrap.recordText) · \(wrap.pointsFor.wrapPoints)").statLabelStyle()
            }

            Text("Top performers").statLabelStyle()

            Grid(alignment: .leading, horizontalSpacing: Spacing.md, verticalSpacing: Spacing.lg) {
                ForEach(Array(performers.enumerated()), id: \.element.id) { index, performer in
                    GridRow(alignment: .firstTextBaseline) {
                        // Size carries the ranking, so the order survives being
                        // read at thumbnail scale with the names illegible.
                        Text(performer.points.wrapPoints)
                            .displayStyle(index == 0 ? .large : .medium)
                            .foregroundStyle(index == 0 ? Palette.textPrimary : Palette.textSecondary)

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(performer.name)
                                .font(index == 0 ? Typography.headline : Typography.body)
                                .foregroundStyle(Palette.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text(performer.subtitle)
                                .font(Typography.caption)
                                .foregroundStyle(Palette.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer(minLength: Spacing.xs)

            HStack(alignment: .bottom) {
                highlightBlock
                Spacer(minLength: Spacing.md)
                Wordmark(tone: .solid)
            }
        }
    }

    // MARK: - Cover
    //
    // Magazine cover. One statement, one number, and a great deal of air. The
    // performers drop to a credit block at the foot of the card, the way a cover
    // line sits above the small type.
    //
    // The number is the manager's score in their best league that week — never a
    // total across leagues, because the statement above it names one league and
    // the two must agree.

    private var cover: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: Spacing.sm) {
                Text(wrap.weekText).statLabelStyle()

                Capsule()
                    .fill(Palette.accent)
                    .frame(width: Spacing.xl, height: Stroke.border * 2)
            }

            Spacer(minLength: Spacing.lg)

            VStack(spacing: Spacing.sm) {
                Text(coverStatement)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(coverNumber)
                    .displayStyle(.hero)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(coverCaption)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
                    // Two lines, because leagues are called things like "The
                    // Wednesday Night Bootleg League" and an ellipsis on a card
                    // somebody posts reads as unfinished work.
                    .lineLimit(2)
            }

            Spacer(minLength: Spacing.lg)

            VStack(spacing: Spacing.sm) {
                Text("Top performers").statLabelStyle()

                // A grid, not three centred rows: centring each line separately
                // leaves the names and the numbers wobbling around a ragged
                // middle, which reads as an accident rather than a credit block.
                Grid(horizontalSpacing: Spacing.sm, verticalSpacing: Spacing.xs) {
                    ForEach(performers) { performer in
                        GridRow {
                            Text(performer.name)
                                .font(Typography.callout)
                                .foregroundStyle(Palette.textSecondary)
                                .gridColumnAlignment(.trailing)

                            Text(performer.points.wrapPoints)
                                .font(Typography.callout)
                                .monospacedDigit()
                                .foregroundStyle(Palette.textPrimary)
                                .gridColumnAlignment(.leading)
                        }
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            Spacer(minLength: Spacing.lg)

            Wordmark(tone: .solid)
        }
        .frame(maxWidth: .infinity)
    }

    /// The cover's statement: the week's story if there is one, else the result.
    private var coverStatement: String {
        wrap.highlight?.headline ?? wrap.resultLine
    }

    /// The best league's own score, so the statement and the number agree.
    private var coverNumber: String {
        (wrap.leagues.first?.points ?? wrap.pointsFor).wrapPoints
    }

    private var coverCaption: String {
        guard let league = wrap.leagues.first else { return wrap.recordText }
        guard let result = league.result, let opponent = league.opponentName else {
            return league.leagueName
        }
        let verb = switch result {
        case .win: "beat"
        case .loss: "lost to"
        case .tie: "tied"
        }
        return "\(league.leagueName) · \(verb) \(opponent)"
    }

    // MARK: - Shared

    private var highlightBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let highlight = wrap.highlight {
                Text(highlight.headline)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if let caption = highlight.caption {
                    Text(caption)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                }
            } else {
                Text(wrap.recordText)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Scaled presentation

/// A wrap card drawn at a given width.
///
/// The card is always laid out at its true size and then scaled, rather than
/// being re-laid-out smaller. A 34.2 that became 11pt type at thumbnail size
/// would be a different design — this way the thumbnail is honestly a picture of
/// the thing that gets exported, which is the only way to judge one.
struct WrapCardScaled: View {
    let wrap: WeeklyWrap
    var style: WrapCardStyle = .scoreline
    var format: WrapFormat = .story
    let width: CGFloat

    private var scale: CGFloat { width / format.size.width }

    var body: some View {
        WrapCardView(wrap: wrap, style: style, format: format)
            .scaleEffect(scale, anchor: .topLeading)
            // `alignment: .topLeading` is the whole trick. `scaleEffect` does not
            // change the view's layout size, so the frame below still positions a
            // 360×640 box — and centring that box inside a 104-point thumbnail
            // puts the drawn content entirely outside the visible window. The
            // symptom is a thumbnail that renders as an empty rectangle.
            .frame(width: width, height: format.size.height * scale, alignment: .topLeading)
            // Rounded here and not in the card: this is the app's presentation
            // of it. The exported image keeps its square corners.
            .clipShape(RoundedRectangle.soft(Radius.hero * scale))
            .overlay(
                RoundedRectangle.soft(Radius.hero * scale)
                    .strokeBorder(Palette.divider, lineWidth: Stroke.hairline)
            )
            .elevation(.lifted)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.summary(wrap))
    }

    /// One sentence for VoiceOver, since the card itself is a picture.
    static func summary(_ wrap: WeeklyWrap) -> String {
        var parts = ["Week \(wrap.week), \(wrap.recordText)"]
        if let highlight = wrap.highlight { parts.append(highlight.headline) }
        if let best = wrap.performers.first {
            parts.append("\(best.name) led with \(best.points.wrapPoints)")
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Previews

/// All three layouts, both formats, side by side — the comparison the design
/// decision actually gets made from.
#Preview("Wrap cards — compare all") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            ForEach(WrapFormat.allCases) { format in
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader(format.label, subtitle: format.ratioText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Spacing.md) {
                            ForEach(WrapCardStyle.allCases) { style in
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    WrapCardScaled(
                                        wrap: .sample, style: style,
                                        format: format, width: 260
                                    )
                                    Text(style.label)
                                        .font(Typography.caption)
                                        .foregroundStyle(Palette.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.screen)
                    }
                    .padding(.horizontal, -Spacing.screen)
                }
            }
        }
        .padding(Spacing.screen)
    }
    .gradientBackground()
}

/// The thumbnail test: if a layout stops reading here, it does not work in a feed.
#Preview("Wrap cards — thumbnail scale") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach(WrapFormat.allCases) { format in
                HStack(alignment: .top, spacing: Spacing.md) {
                    ForEach(WrapCardStyle.allCases) { style in
                        WrapCardScaled(
                            wrap: .sample, style: style, format: format, width: 96
                        )
                    }
                }
            }
        }
        .padding(Spacing.screen)
    }
    .gradientBackground()
}

#Preview("Wrap card — one league, a heartbreak") {
    ScrollView(.horizontal) {
        HStack(spacing: Spacing.md) {
            ForEach(WrapCardStyle.allCases) { style in
                WrapCardScaled(
                    wrap: .sampleSingleLeague, style: style,
                    format: .story, width: 280
                )
            }
        }
        .padding(Spacing.screen)
    }
    .gradientBackground()
}
