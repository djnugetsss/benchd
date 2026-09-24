import SwiftUI

/// Hosts the three onboarding screens and the movement between them.
///
/// **On transitions:** DESIGN.md §7 rules out slides for content — they read as
/// chrome — so steps cross-fade with a slight scale instead. The direction of
/// travel is carried by the progress marks at the top rather than by motion.
struct OnboardingFlowView: View {
    let startingStep: OnboardingStep
    @Environment(AppSession.self) private var session

    @State private var step: OnboardingStep
    @State private var signIn: SignInViewModel?
    @State private var connect: ConnectSleeperViewModel?

    init(startingAt startingStep: OnboardingStep) {
        self.startingStep = startingStep
        _step = State(initialValue: startingStep)
    }

    var body: some View {
        ZStack {
            // The bloom is a brand moment, and onboarding is the one place in
            // the app that earns it.
            GradientBackground(showsBloom: true)

            VStack(spacing: 0) {
                OnboardingProgress(current: step)
                    .padding(.top, Spacing.md)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(Motion.gentle, value: step)
        .task { prepareModels() }
        .onChange(of: session.auth.sessionState) { _, newValue in
            // Signing in never leaves the flow, so the step has to advance
            // itself the moment the session lands.
            if newValue.userID != nil, step != .connectSleeper {
                prepareModels()
                step = .connectSleeper
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            WelcomeScreen { step = .signIn }
                .transition(Motion.appear)

        case .signIn:
            if let signIn {
                SignInScreen(model: signIn) { step = .welcome }
                    .transition(Motion.appear)
            }

        case .connectSleeper:
            if let connect {
                ConnectSleeperScreen(model: connect)
                    .transition(Motion.appear)
            } else {
                // Signed in but the profile id hasn't arrived yet.
                ProgressPlaceholder()
                    .transition(Motion.appear)
            }
        }
    }

    private func prepareModels() {
        if signIn == nil {
            signIn = SignInViewModel(auth: session.auth)
        }
        if connect == nil, let profileID = session.auth.sessionState.userID {
            connect = ConnectSleeperViewModel(
                profileID: profileID,
                onConnected: { account in session.markSleeperConnected(account) }
            )
        }
    }
}

/// A brief, quiet hold. Not a spinner on an empty screen — skeleton shapes that
/// hint at what is about to arrive, per DESIGN.md §8.
struct ProgressPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SkeletonBlock(width: 120, height: 12)
            SkeletonBlock(width: 220, height: 30)
            SkeletonBlock(height: 12)
        }
        .padding(.horizontal, Spacing.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Onboarding") {
    OnboardingFlowView(startingAt: .welcome)
        .environment(AppSession(auth: AuthService(client: nil)))
}
