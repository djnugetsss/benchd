import SwiftUI

/// The wait after connecting Sleeper.
///
/// A first sync can take a minute or more, and this is the only time anyone
/// will ever watch it. So it is not a spinner over a dimmed screen: it is a
/// quiet page that tells you what it just found, one line at a time.
///
/// The reveals arrive newest-last and the older ones fade back to tertiary
/// rather than scrolling away, so the eye stays on the newest line without
/// anything moving underneath it.
struct FirstSyncScreen: View {
    @Bindable var model: FirstSyncViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: Spacing.lg)
                .frame(maxHeight: Spacing.xxl)

            if model.isFailed {
                failure
            } else {
                working

                Spacer(minLength: Spacing.xl)

                // Worth saying, and it anchors a composition that is otherwise
                // more than half empty: the sync runs in an edge function, so
                // leaving the app genuinely does not stop it.
                Text("You can close the app — the sync keeps running.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.isFailed {
                Spacer(minLength: Spacing.xl)
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.gentle, value: model.phase)
        .task { await model.start() }
        .onDisappear { model.cancel() }
    }

    // MARK: - Working

    private var working: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Building your career")
                    .titleStyle()

                Text("We're reading your Sleeper history. This takes a minute the first time, and never again.")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ProgressTrack(value: model.progress)

            reveals
        }
    }

    /// The found-so-far feed. Newest at the bottom in full ink; each older line
    /// a step quieter, so the list reads as a trail rather than a log.
    private var reveals: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(model.visibleReveals.enumerated()), id: \.element.id) { index, event in
                let distanceFromNewest = model.visibleReveals.count - 1 - index

                Text(event.message)
                    .font(distanceFromNewest == 0 ? Typography.body : Typography.callout)
                    .foregroundStyle(tone(forStepsBack: distanceFromNewest))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(Motion.appear)
            }
        }
        .animation(Motion.gentle, value: model.visibleReveals.map(\.id))
        .frame(minHeight: 120, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.visibleReveals.last?.message ?? "Syncing")
    }

    private func tone(forStepsBack steps: Int) -> Color {
        switch steps {
        case 0: Palette.textPrimary
        case 1: Palette.textSecondary
        default: Palette.textTertiary
        }
    }

    // MARK: - Failure

    private var failure: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("We couldn't finish")
                    .titleStyle()

                Text("Your account is connected — we just couldn't read all of it this time. Nothing is lost, and trying again picks up where it stopped.")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if case .failed(let reason) = model.phase {
                InlineMessage(reason)
            }

            PrimaryButton("Try again") {
                Task { await model.retry() }
            }
        }
    }
}

// MARK: - Previews

#Preview("First sync — running") {
    ZStack {
        GradientBackground(showsBloom: true)
        FirstSyncScreen(model: .preview(stage: .running))
    }
}

#Preview("First sync — failed") {
    ZStack {
        GradientBackground(showsBloom: true)
        FirstSyncScreen(model: .preview(stage: .failed))
    }
}

extension FirstSyncViewModel {
    /// Preview seam. Nothing in the app calls this.
    static func preview(stage: PreviewStage) -> FirstSyncViewModel {
        let model = FirstSyncViewModel(accountID: UUID(), sync: SyncService(client: nil))
        model.applyPreview(stage)
        return model
    }

    enum PreviewStage { case running, failed }
}
