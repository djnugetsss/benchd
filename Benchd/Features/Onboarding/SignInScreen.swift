import SwiftUI

/// One field, one button. No password, no provider buttons, no "or continue
/// with" divider — a magic link is the whole method in v1, and the screen should
/// look like it was designed for that rather than stripped down from something
/// bigger.
struct SignInScreen: View {
    @Bindable var model: SignInViewModel
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content high, actions low. A symmetric pair of Spacers floated the
            // whole screen in the middle with a third of the page empty above.
            Spacer(minLength: Spacing.lg)
                .frame(maxHeight: Spacing.xxl)

            switch model.phase {
            case .editing, .sending:
                form
            case .sent(let email):
                sentConfirmation(email: email)
            }

            Spacer(minLength: Spacing.xl)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.xl)
        .animation(Motion.gentle, value: model.phase)
    }

    // MARK: - Editing

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("What's your email?")
                    .titleStyle()

                Text("We'll send a link that signs you in. No password to remember, nothing to choose.")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                InputField(
                    label: "Email",
                    placeholder: "you@example.com",
                    text: $model.email,
                    keyboard: .emailAddress,
                    contentType: .emailAddress,
                    submitLabel: .go,
                    isEnabled: model.phase != .sending,
                    hasError: model.failure == .invalidEmail,
                    onSubmit: { Task { await model.send() } }
                )

                if let failure = model.failure {
                    InlineMessage(failure.message)
                        .transition(Motion.appear)
                }
            }

            VStack(spacing: Spacing.xxs) {
                PrimaryButton(
                    model.phase == .sending ? "Sending…" : "Send magic link",
                    isEnabled: model.canSubmit
                ) {
                    Task { await model.send() }
                }

                // "Back" as a full-width bordered button carried the same visual
                // weight as the real action and made the screen read as a form.
                TertiaryButton("Back", action: onBack)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(Motion.gentle, value: model.failure)
    }

    // MARK: - Sent

    private func sentConfirmation(email: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Check your email")
                    .titleStyle()

                Text("We sent a sign-in link to")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)

                // The address is the one thing worth checking at a glance, so it
                // gets the screen's single accent. An earlier ring-and-dot mark
                // above the headline read as a stray radio button.
                Text(email)
                    .font(Typography.body)
                    .foregroundStyle(Palette.accentInk)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Palette.accentTint, in: RoundedRectangle.soft(Radius.sm))
                    .padding(.top, Spacing.xxs)

                Text("Open it on this device and you'll come straight back here. The link works once, and expires after an hour.")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.xs)
            }

            if let failure = model.failure {
                InlineMessage(failure.message)
                    .transition(Motion.appear)
            }

            VStack(spacing: Spacing.xxs) {
                SecondaryButton(resendTitle, isEnabled: model.canResend) {
                    Task { await model.resend() }
                }

                TertiaryButton("Use a different email") {
                    model.editEmail()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .transition(Motion.appear)
    }

    private var resendTitle: String {
        model.resendCooldown > 0
            ? "Resend in \(model.resendCooldown)s"
            : "Resend link"
    }
}

#Preview("Sign in — empty") {
    ZStack {
        GradientBackground()
        SignInScreen(model: SignInViewModel(auth: AuthService(client: nil)), onBack: {})
    }
}

#Preview("Sign in — sent") {
    ZStack {
        GradientBackground()
        SignInScreen(
            model: SignInViewModel(
                auth: AuthService(client: nil),
                phase: .sent(email: "ansh@example.com"),
                email: "ansh@example.com"
            ),
            onBack: {}
        )
    }
}

#Preview("Sign in — error") {
    ZStack {
        GradientBackground()
        SignInScreen(
            model: SignInViewModel(auth: AuthService(client: nil), phase: .editing, email: "nope"),
            onBack: {}
        )
    }
}
