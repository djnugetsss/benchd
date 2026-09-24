import SwiftUI

/// Everywhere the signed-in app can navigate to.
///
/// One route type for the whole app rather than one per tab. A player page
/// pushed from the Players list and the same page pushed from a rivalry on the
/// profile are the same screen, and a shared route is what stops them becoming
/// two — whichever stack is on top resolves the value the same way.
///
/// Routes are values, not views: a stack's path is `Hashable` data, which is
/// what makes "restore where they were" a matter of saving an array later on.
enum AppRoute: Hashable, Sendable {
    case settings
    /// An NFL player's page — v1 scope item 4.
    case player(id: String)
    /// One league-season, where a row of the career timeline will lead.
    case leagueSeason(leagueID: String, season: Int)
    /// The head-to-head history against one opponent.
    case rivalry(opponentKey: String, name: String)

    /// What the pushed screen is called. Lives on the route so a destination and
    /// its back button cannot disagree about the name.
    var title: String {
        switch self {
        case .settings: "Settings"
        case .player: "Player"
        case .leagueSeason: "Season"
        case .rivalry(_, let name): name
        }
    }
}

extension View {
    /// Teaches a `NavigationStack` every route in the app.
    ///
    /// Applied once per stack in `AppShellView`, so adding a destination is a
    /// change in one place rather than in each tab that might reach it.
    func appNavigationDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .settings:
                SettingsScreen()
            default:
                UnbuiltDestination(route: route)
            }
        }
    }
}

/// A destination whose screen has not been built yet.
///
/// Deliberately a real, designed screen rather than a blank one: the navigation
/// pattern is in place now, and a push that lands somewhere honest is how that
/// gets verified before any of these screens exist.
struct UnbuiltDestination: View {
    let route: AppRoute

    var body: some View {
        ScrollView {
            EmptyState(
                title: "Not built yet",
                message: "\(route.title) pages land in a later pass. The way here already works.",
                systemImage: "square.dashed"
            )
            .padding(.top, Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .gradientBackground()
    }
}

#Preview("Unbuilt destination") {
    NavigationStack {
        UnbuiltDestination(route: .player(id: "4046"))
    }
}
