import SwiftUI

/// Two fields and one button.
///
/// Kept as airy as a sign-in screen can be: labels above the fields, one action,
/// and the switch between creating an account and signing in as a quiet line of
/// text rather than a segmented control at the top. A form is what this screen
/// must not look like — everything that could be a field is left out, and the
/// password rule is stated in advance so nobody meets it as a rejection.
struct SignInScreen: View {
    @Bindable var model: SignInViewModel
    var onBack: () -> Void

    @FocusState private var focus: Field?

    private enum Field: Hashable { case email, password }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content high, actions low.
            Spacer(minLength: Spacing.lg)
                .frame(maxHeight: Spacing.xxl)

            switch model.phase {
            case .editing, .submitting:
                form
            case .awaitingConfirmation(let email):
                confirmation(email: email)
            }

            Spacer(minLength: Spacing.xl)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.xl)
        .animation(Motion.gentle, value: model.phase)
        .animation(Motion.gentle, value: model.mode)
    }

    // MARK: - The form

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(model.mode.title)
                    .titleStyle()

                Text(model.mode.subtitle)
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                InputField(
                    label: "Email",
                    placeholder: "you@example.com",
                    text: $model.email,
                    keyboard: .emailAddress,
                    contentType: .username,
                    submitLabel: .next,
                    isEnabled: !model.isSubmitting,
                    hasError: model.emailHasError,
                    onSubmit: { focus = .password }
                )
                .focused($focus, equals: .email)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    InputField(
                        label: "Password",
                        placeholder: model.mode == .signUp ? "Choose a password" : "Your password",
                        text: $model.password,
                        contentType: model.mode == .signUp ? .newPassword : .password,
                        submitLabel: .go,
                        isEnabled: !model.isSubmitting,
                        hasError: model.passwordHasError,
                        isSecure: true,
                        onSubmit: { Task { await model.submit() } }
                    )
                    .focused($focus, equals: .password)

                    // The rule, before it can be broken. `textTertiary` while it
                    // is guidance; the field's own border carries the error.
                    if let requirement = model.passwordRequirement {
                        Text(requirement)
                            .font(Typography.caption)
                            .foregroundStyle(
                                model.passwordHasError ? Palette.negative : Palette.textTertiary
                            )
                            .padding(.leading, Spacing.xxs)
                            .transition(.opacity)
                    }
                }

                if let failure = model.failure {
                    InlineMessage(failure.message)
                        .transition(Motion.appear)
                }
            }

            // The actions sit at the foot of the screen rather than under the
            // fields: with the keyboard up that puts the button just above it,
            // and with the keyboard down it stops the screen reading as a form
            // with a gap at the bottom.
            Spacer(minLength: Spacing.xl)

            VStack(spacing: Spacing.xxs) {
                PrimaryButton(
                    model.isSubmitting ? "One moment…" : model.mode.action,
                    isEnabled: model.canSubmit
                ) {
                    focus = nil
                    Task { await model.submit() }
                }

                TertiaryButton(model.mode.switchPrompt, isEnabled: !model.isSubmitting) {
                    focus = nil
                    model.toggleMode()
                }

                TertiaryButton("Back", isEnabled: !model.isSubmitting, action: onBack)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(Motion.gentle, value: model.failure)
        .animation(Motion.gentle, value: model.passwordHasError)
    }

    // MARK: - Awaiting confirmation

    /// Only reachable when the Supabase project has email confirmation turned on.
    /// Without this the app would look like nothing happened, because a sign-up
    /// that needs confirming produces no session.
    private func confirmation(email: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Confirm your email")
                    .titleStyle()

                Text("We sent a confirmation link to")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)

                // The address is the one thing worth checking at a glance, so it
                // gets the screen's single accent.
                Text(email)
                    .font(Typography.body)
                    .foregroundStyle(Palette.accentInk)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Palette.accentTint, in: RoundedRectangle.soft(Radius.sm))
                    .padding(.top, Spacing.xxs)

                Text("Open it, then come back and sign in.")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.xs)
            }

            VStack(spacing: Spacing.xxs) {
                SecondaryButton("Sign in") {
                    model.setMode(.signIn)
                    model.editEmail()
                }

                TertiaryButton("Use a different email") {
                    model.setMode(.signUp)
                    model.editEmail()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .transition(Motion.appear)
    }
}

#Preview("Sign in — create account") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(model: SignInViewModel(auth: AuthService(client: nil)), onBack: {})
    }
}

#Preview("Sign in — returning") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(
            model: SignInViewModel(auth: AuthService(client: nil), mode: .signIn),
            onBack: {}
        )
    }
}

#Preview("Sign in — password too short") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(
            model: SignInViewModel(
                auth: AuthService(client: nil),
                email: "ansh@example.com",
                password: "short"
            ),
            onBack: {}
        )
    }
}

#Preview("Sign in — wrong password") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(
            model: SignInViewModel(
                auth: AuthService(client: nil),
                mode: .signIn,
                email: "ansh@example.com",
                password: "wrongpassword",
                failure: .invalidCredentials
            ),
            onBack: {}
        )
    }
}

#Preview("Sign in — email taken") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(
            model: SignInViewModel(
                auth: AuthService(client: nil),
                mode: .signIn,
                email: "ansh@example.com",
                failure: .emailAlreadyRegistered
            ),
            onBack: {}
        )
    }
}

#Preview("Sign in — offline") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(
            model: SignInViewModel(
                auth: AuthService(client: nil),
                email: "ansh@example.com",
                password: "longenoughpassword",
                failure: .network
            ),
            onBack: {}
        )
    }
}

#Preview("Sign in — confirm your email") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(
            model: SignInViewModel(
                auth: AuthService(client: nil),
                phase: .awaitingConfirmation(email: "ansh@example.com")
            ),
            onBack: {}
        )
    }
}
