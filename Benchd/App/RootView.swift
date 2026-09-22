import SwiftUI

/// Routes between the launch hold, onboarding, and the signed-in shell.
///
/// The route is derived from `AppSession`, never stored here — there is no way
/// for this view to show onboarding to someone who is already signed in.
struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ZStack {
            switch session.route {
            case .launching:
                LaunchScreen()
                    .transition(.opacity)

            case .onboarding(let startingStep):
                OnboardingFlowView(startingAt: startingStep)
                    // Identity keyed on the entry step so returning from a magic
                    // link rebuilds the flow at the right place rather than
                    // reusing the signed-out one.
                    .id(startingStep)
                    .transition(Motion.appear)

            case .firstSync(let accountID):
                OnboardingBackdrop {
                    FirstSyncScreen(
                        model: FirstSyncViewModel(
                            accountID: accountID,
                            onFinished: { Task { await session.markSyncComplete() } }
                        )
                    )
                }
                .id(accountID)
                .transition(Motion.appear)

            case .main:
                AppShellView()
                    .transition(Motion.appear)
            }
        }
        .animation(Motion.soft, value: session.route)
        .task(id: session.auth.sessionState) {
            await session.refreshConnectionState()
            await session.touchLastSeen()
        }
    }
}

/// The gradient canvas onboarding-era screens sit on. Keeps the bloom and the
/// margins identical across the flow and the first sync, so moving between them
/// does not shift the page underneath.
struct OnboardingBackdrop<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            GradientBackground(showsBloom: true)
            content
        }
    }
}

/// The hold while a stored session is restored. Deliberately almost empty — a
/// spinner here would be the first thing anyone sees.
struct LaunchScreen: View {
    var body: some View {
        ZStack {
            GradientBackground(showsBloom: true)

            Text("Benchd")
                .titleStyle()
                .opacity(0.9)
        }
    }
}

#Preview("Launch") {
    LaunchScreen()
}

#Preview("Root") {
    RootView()
        .environment(AppSession(auth: AuthService(client: nil)))
}
