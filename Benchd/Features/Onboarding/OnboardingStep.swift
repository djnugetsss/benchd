import Foundation

/// The three onboarding screens.
///
/// Not a linear wizard: someone who signed in last week but never finished
/// connecting Sleeper resumes at `connectSleeper` on a cold launch.
/// `AppSession` decides where to enter; the flow view handles the rest.
enum OnboardingStep: Hashable, CaseIterable, Sendable {
    case welcome
    case signIn
    case connectSleeper

    /// Position in the progress indicator, 1-based.
    var displayIndex: Int {
        switch self {
        case .welcome: 1
        case .signIn: 2
        case .connectSleeper: 3
        }
    }
}
