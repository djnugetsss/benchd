import SwiftUI

/// The last onboarding step: one field, then a confirmation card.
struct ConnectSleeperScreen: View {
    @Bindable var model: ConnectSleeperViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: Spacing.lg)
                .frame(maxHeight: Spacing.xxl)

            VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                heading

                switch model.phase {
                case .entry, .searching:
                    entry
                case .confirming(let user), .saving(let user):
                    confirmation(user)
                }
            }

            Spacer(minLength: Spacing.xl)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.xl)
        .animation(Motion.gentle, value: model.phase)
        .animation(Motion.gentle, value: model.errorMessage)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(isConfirming ? "Is this you?" : "Connect Sleeper")
                .titleStyle()

            Text(isConfirming
                 ? "We found this account. Confirm it's yours and we'll build your career profile from it."
                 : "Your username is all we need — Sleeper's data is public, so there's nothing to authorise.")
                .font(Typography.callout)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var isConfirming: Bool {
        switch model.phase {
        case .confirming, .saving: true
        case .entry, .searching: false
        }
    }

    // MARK: - Entry

    private var entry: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                InputField(
                    label: "Sleeper username",
                    placeholder: "username",
                    text: $model.username,
                    submitLabel: .search,
                    isEnabled: !model.isBusy,
                    hasError: model.fieldHasError,
                    onSubmit: { Task { await model.search() } }
                )

                if let message = model.errorMessage {
                    InlineMessage(message)
                        .transition(Motion.appear)
                }
            }

            Spacer(minLength: Spacing.sectionGap)
                .frame(maxHeight: Spacing.sectionGap)

            PrimaryButton(
                model.phase == .searching ? "Looking…" : "Continue",
                isEnabled: model.canSearch
            ) {
                Task { await model.search() }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .transition(Motion.appear)
    }

    // MARK: - Confirmation

    private func confirmation(_ user: SleeperUser) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Card(padding: Spacing.xl, radius: Radius.cardLarge, elevation: .lifted) {
                VStack(spacing: Spacing.md) {
                    Avatar(name: user.bestName, imageURL: user.avatarURL, size: .hero)

                    VStack(spacing: Spacing.xxs) {
                        Text(user.bestName)
                            .font(Typography.headline)
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if let username = user.username {
                            Text("@\(username)")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    PillTag("Sleeper", tone: .neutral)
                        .padding(.top, Spacing.xxs)
                }
                .frame(maxWidth: .infinity)
            }

            if let message = model.errorMessage {
                InlineMessage(message)
                    .transition(Motion.appear)
            }

            VStack(spacing: Spacing.xxs) {
                PrimaryButton(
                    model.isBusy ? "Connecting…" : "That's me",
                    tone: .accent,
                    isEnabled: !model.isBusy
                ) {
                    Task { await model.confirm() }
                }

                TertiaryButton("Not me", isEnabled: !model.isBusy) {
                    model.reject()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .transition(Motion.appear)
    }
}

// MARK: - Previews

/// A lookup that answers instantly, so every state is previewable offline.
private struct StubLookup: SleeperUserLookup {
    var result: Result<SleeperUser, SleeperError>
    func user(username: String) async throws -> SleeperUser { try result.get() }
}

private let sampleUser = SleeperUser(
    userID: "12345", username: "anshm", displayName: "Ansh", avatar: nil
)

#Preview("Connect — entry") {
    ZStack {
        GradientBackground()
        ConnectSleeperScreen(model: ConnectSleeperViewModel(
            profileID: UUID(),
            lookup: StubLookup(result: .success(sampleUser))
        ))
    }
}

#Preview("Connect — not found") {
    let model = ConnectSleeperViewModel(
        profileID: UUID(),
        lookup: StubLookup(result: .failure(.userNotFound))
    )
    model.username = "nobody"
    return ZStack {
        GradientBackground()
        ConnectSleeperScreen(model: model)
    }
    .task { await model.search() }
}

#Preview("Connect — confirming") {
    let model = ConnectSleeperViewModel(
        profileID: UUID(),
        lookup: StubLookup(result: .success(sampleUser))
    )
    model.username = "anshm"
    return ZStack {
        GradientBackground()
        ConnectSleeperScreen(model: model)
    }
    .task { await model.search() }
}
