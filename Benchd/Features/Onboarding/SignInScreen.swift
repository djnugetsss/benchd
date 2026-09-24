import AuthenticationServices
import SwiftUI

/// One button. No field, no password, no "or continue with" divider — Apple is
/// the whole method, and the screen should look like it was designed for that
/// rather than stripped down from something bigger.
///
/// **On the Apple button.** Apple's HIG requires its own button, and the default
/// is a black slab that would be the loudest object in the app by some distance.
/// The outline style is the one variant that sits inside this palette: a white
/// surface with a hairline edge, which is what every other raised thing in Benchd
/// already is. It is given the same height and radius as `PrimaryButton` so it
/// reads as our button that happens to carry Apple's mark, rather than as a
/// foreign object dropped onto the page.
struct SignInScreen: View {
    @Bindable var model: SignInViewModel
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content high, actions low.
            Spacer(minLength: Spacing.lg)
                .frame(maxHeight: Spacing.xxl)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Sign in")
                    .titleStyle()

                Text("One tap with Apple. No password to remember, nothing to check your email for.")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.xl)

            VStack(spacing: Spacing.sm) {
                if let failure = model.failure {
                    InlineMessage(failure.message)
                        .transition(Motion.appear)
                }

                appleButton

                Text("Benchd sees your name only if you choose to share it, and never needs your email address.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xxs)

                TertiaryButton("Back", isEnabled: !model.isAuthenticating, action: onBack)
                    .padding(.top, Spacing.xxs)
            }

            Spacer(minLength: Spacing.xl)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.xl)
        .animation(Motion.gentle, value: model.failure)
        .animation(Motion.gentle, value: model.phase)
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            model.prepare(request)
        } onCompletion: { result in
            Task { await model.handle(result) }
        }
        .signInWithAppleButtonStyle(.whiteOutline)
        .frame(height: buttonHeight)
        .clipShape(RoundedRectangle.soft(Radius.md))
        .opacity(model.isAuthenticating ? 0.6 : 1)
        .disabled(model.isAuthenticating)
        .accessibilityLabel("Sign in with Apple")
    }

    /// Matched to `PrimaryButton`: its label is 16pt with `Spacing.md + 2` above
    /// and below. Apple's button has no way to take our padding, so the height
    /// is matched by hand and kept on the spacing scale.
    private var buttonHeight: CGFloat { Spacing.xxxl }
}

#Preview("Sign in") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(model: SignInViewModel(auth: AuthService(client: nil)), onBack: {})
    }
}

#Preview("Sign in — signing in") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(
            model: SignInViewModel(auth: AuthService(client: nil), phase: .authenticating),
            onBack: {}
        )
    }
}

#Preview("Sign in — Apple failed") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(
            model: SignInViewModel(
                auth: AuthService(client: nil), phase: .idle, failure: .appleUnavailable
            ),
            onBack: {}
        )
    }
}

#Preview("Sign in — credential revoked") {
    ZStack {
        GradientBackground(showsBloom: true)
        SignInScreen(
            model: SignInViewModel(
                auth: AuthService(client: nil), phase: .idle, failure: .appleRevoked
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
                auth: AuthService(client: nil), phase: .idle, failure: .network
            ),
            onBack: {}
        )
    }
}
