import SwiftUI

/// The Wraps tab: this week's card as a showpiece, and every week before it.
///
/// The card is the product here, so the screen around it is deliberately almost
/// nothing — a toggle, two actions, and a strip of earlier weeks. Anything else
/// would be furniture competing with the thing people came to look at.
struct WrapsScreen: View {
    @Environment(AppSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: WrapsViewModel?

    var body: some View {
        TabScaffold(title: "Wraps") {
            if let model {
                WrapsContent(model: model)
            } else {
                WrapsSkeleton(format: .story)
            }
        }
        .refreshable { await model?.refresh() }
        .task(id: reloadKey) { await prepareAndLoad() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await session.refreshAfterForeground() }
        }
    }

    private var reloadKey: String {
        "\(session.connectedAccount?.id.uuidString ?? "none")-\(session.syncGeneration)"
    }

    private func prepareAndLoad() async {
        guard let account = session.connectedAccount else { return }

        if model?.account.id != account.id {
            let created = WrapsViewModel(account: account)
            model = created
            await created.load()
        } else {
            await model?.refresh()
        }
    }
}

// MARK: - Body

struct WrapsContent: View {
    @Bindable var model: WrapsViewModel

    /// Which of the three layouts ships. Changing this line changes the card the
    /// whole app exports — see `WrapCardStyle` for what the other two look like.
    private let style: WrapCardStyle = .cover

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                WrapsSkeleton(format: model.format)

            case .ready:
                if let wrap = model.selected {
                    wrapBody(wrap)
                } else {
                    WrapsSkeleton(format: model.format)
                }

            case .empty:
                EmptyState(
                    title: "No wraps yet",
                    message: "Your first wrap lands once a week of games is final.",
                    systemImage: "sparkles.rectangle.stack"
                )
                .frame(maxWidth: .infinity)

            case .failed(let message):
                EmptyState(title: "We couldn't build your wrap", message: message) {
                    SecondaryButton("Try again") {
                        Task { await model.load() }
                    }
                    .frame(maxWidth: 220)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(Motion.gentle, value: model.state)
    }

    @ViewBuilder
    private func wrapBody(_ wrap: WeeklyWrap) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            showpiece(wrap)
            actions(wrap)

            if !model.history.isEmpty {
                history
            }
        }
    }

    // MARK: - Showpiece

    private func showpiece(_ wrap: WeeklyWrap) -> some View {
        VStack(spacing: Spacing.md) {
            // Sized to the format rather than to the screen, so the whole card is
            // on screen at once. A showpiece you have to scroll to see is not one.
            GeometryReader { proxy in
                let width = min(proxy.size.width, model.format.showpieceHeight * model.format.aspectRatio)

                WrapCardScaled(
                    wrap: wrap,
                    style: style,
                    format: model.format,
                    width: width
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
            .frame(height: model.format.showpieceHeight)
            .animation(Motion.gentle, value: model.format)
            .animation(Motion.gentle, value: wrap.id)

            WrapFormatToggle(format: $model.format)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actions(_ wrap: WeeklyWrap) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                // The share sheet is the growth loop, so it gets the accent tone
                // — the brand moment DESIGN.md §8 reserves it for.
                if let shareable = WrapExporter.shareable(wrap, style: style, format: model.format) {
                    ShareLink(
                        item: shareable,
                        preview: SharePreview(
                            shareable.title,
                            image: Image(uiImage: shareable.image)
                        )
                    ) {
                        PrimaryButtonLabel("Share", tone: .accent, systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SoftPressStyle())
                }

                SecondaryButton("Save", systemImage: "arrow.down.to.line") {
                    Task { await model.saveToPhotos(wrap, style: style) }
                }
                .frame(maxWidth: saveButtonWidth)
            }

            saveStatus
        }
    }

    /// Narrower than Share: saving is the second choice, and the two buttons
    /// should not read as equals. Derived from the scale so it stays on the grid.
    private var saveButtonWidth: CGFloat { Spacing.xxxl + Spacing.huge }

    @ViewBuilder
    private var saveStatus: some View {
        switch model.saveState {
        case .idle:
            EmptyView()
        case .saving:
            statusText("Saving…", tone: Palette.textTertiary)
        case .saved:
            statusText("Saved to Photos", tone: Palette.textSecondary)
        case .failed(let message):
            statusText(message, tone: Palette.textSecondary)
        }
    }

    private func statusText(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(tone)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
    }

    // MARK: - History

    private var history: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Earlier weeks", subtitle: "Tap one to bring it up")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    ForEach(model.history) { wrap in
                        Button {
                            model.selectedID = wrap.id
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                WrapCardScaled(
                                    wrap: wrap,
                                    style: style,
                                    format: model.format,
                                    width: thumbnailWidth
                                )

                                Text(wrap.weekText)
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.textSecondary)

                                Text(wrap.recordText)
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.textTertiary)
                            }
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                // The strip runs to both edges of the screen, which is what makes
                // it read as a strip rather than as a row of cards in a box.
                .padding(.horizontal, Spacing.screen)
            }
            .padding(.horizontal, -Spacing.screen)
        }
    }

    /// Small enough that four weeks are reachable in a thumb's sweep, large
    /// enough that the card's hero number is still legible — the size the
    /// thumbnail-scale preview is checked against.
    private var thumbnailWidth: CGFloat { Spacing.xxxl * 2 }
}

// MARK: - Format toggle

/// Story or post. Two taps, no chrome.
struct WrapFormatToggle: View {
    @Binding var format: WrapFormat
    @Namespace private var selection

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(WrapFormat.allCases) { option in
                Button {
                    withAnimation(Motion.gentle) { format = option }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(option.label)
                            .font(Typography.statLabel)
                            .textCase(.uppercase)
                            .tracking(1.2)

                        Text(option.ratioText)
                            .font(Typography.statLabel)
                            .foregroundStyle(Palette.textTertiary)
                    }
                    .foregroundStyle(
                        format == option ? Palette.accentInk : Palette.textSecondary
                    )
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs + 2)
                    .background {
                        if format == option {
                            Capsule()
                                .fill(Palette.accentTint)
                                .matchedGeometryEffect(id: "wrapFormat", in: selection)
                        }
                    }
                }
                .buttonStyle(SoftPressStyle())
            }
        }
        .padding(Spacing.xxs)
        .background(Palette.surfaceSecondary, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card format")
    }
}

// MARK: - Loading

/// The shape of the page, sketched. Never a spinner.
struct WrapsSkeleton: View {
    var format: WrapFormat = .story

    var body: some View {
        VStack(spacing: Spacing.sectionGap) {
            SkeletonBlock(
                width: format.showpieceHeight * format.aspectRatio,
                height: format.showpieceHeight,
                radius: Radius.hero
            )

            HStack(spacing: Spacing.sm) {
                SkeletonBlock(height: 52, radius: Radius.md)
                SkeletonBlock(width: 132, height: 52, radius: Radius.md)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("Wraps — ready") {
    WrapsContent(model: .preview(state: .ready(WeeklyWrap.sampleHistory)))
        .padding(Spacing.screen)
        .frame(maxHeight: .infinity, alignment: .top)
        .gradientBackground()
}

#Preview("Wraps — post format") {
    WrapsContent(model: .preview(state: .ready(WeeklyWrap.sampleHistory), format: .post))
        .padding(Spacing.screen)
        .frame(maxHeight: .infinity, alignment: .top)
        .gradientBackground()
}

#Preview("Wraps — loading") {
    WrapsContent(model: .preview(state: .loading))
        .padding(Spacing.screen)
        .frame(maxHeight: .infinity, alignment: .top)
        .gradientBackground()
}

#Preview("Wraps — no weeks played") {
    WrapsContent(model: .preview(state: .empty))
        .padding(Spacing.screen)
        .frame(maxHeight: .infinity, alignment: .top)
        .gradientBackground()
}

#Preview("Wraps — failed") {
    WrapsContent(model: .preview(state: .failed("You're offline. Pull to refresh once you reconnect.")))
        .padding(Spacing.screen)
        .frame(maxHeight: .infinity, alignment: .top)
        .gradientBackground()
}
