import SwiftUI

/// The three tabs of the signed-in app.
enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case profile, wraps, players

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: "Profile"
        case .wraps: "Wraps"
        case .players: "Players"
        }
    }

    /// Outline when unselected, filled when selected — the weight change is what
    /// carries selection, with the accent as reinforcement rather than the only
    /// signal. Keeps the bar legible in grayscale, per DESIGN.md §2.
    var icon: String {
        switch self {
        case .profile: "person"
        case .wraps: "sparkles.rectangle.stack"
        case .players: "figure.american.football"
        }
    }

    var selectedIcon: String {
        switch self {
        case .profile: "person.fill"
        case .wraps: "sparkles.rectangle.stack.fill"
        case .players: "figure.american.football"
        }
    }
}

/// The signed-in shell.
///
/// The system tab bar is hidden and replaced: its default chrome is an opaque
/// grey blur with system-blue tint, which is exactly the "default-looking
/// SwiftUI screen" CLAUDE.md forbids. `TabView` is kept underneath so each tab
/// retains its own state and lazily loads.
///
/// **Navigation.** Each tab owns a `NavigationStack` and its own path, so a
/// player page pushed in Players is still there after a trip to Profile and
/// back — one shared stack would collapse all three histories into one. Every
/// stack resolves the same `AppRoute` values via `appNavigationDestinations()`,
/// which is what lets the profile and the players list push the same screen.
///
/// The bars themselves are styled once, in `NavigationAppearance`.
struct AppShellView: View {
    @State private var selection: AppTab

    /// Opens on a given tab. Defaults to Profile, and exists so a notification
    /// or a deep link can land somewhere specific without the shell having to
    /// grow a second way in.
    init(initialTab: AppTab = .profile) {
        _selection = State(initialValue: initialTab)
    }

    /// One path per tab. A missing entry is an empty path — a tab that has never
    /// pushed anything does not need a stored one.
    @State private var paths: [AppTab: NavigationPath] = [:]

    var body: some View {
        ZStack(alignment: .bottom) {
            GradientBackground()

            TabView(selection: $selection) {
                ForEach(AppTab.allCases) { tab in
                    NavigationStack(path: path(for: tab)) {
                        tabContent(tab)
                            .appNavigationDestinations()
                    }
                    .tag(tab)
                    .toolbar(.hidden, for: .tabBar)
                }
            }

            BenchdTabBar(selection: $selection) { tab in
                // Tapping the tab you are already on returns to its root, which
                // is the gesture every iOS user already has in their hands.
                paths[tab] = NavigationPath()
            }
        }
    }

    private func path(for tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { paths[tab] ?? NavigationPath() },
            set: { paths[tab] = $0 }
        )
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .profile: ProfileScreen()
        case .wraps: WrapsScreen()
        case .players: PlayersScreen()
        }
    }
}

/// A light, airy tab bar: a translucent surface with a hairline top edge, and
/// accent blue reserved for the selected item.
struct BenchdTabBar: View {
    @Binding var selection: AppTab
    /// Called when the already-selected tab is tapped again.
    var onReselect: (AppTab) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                item(tab)
            }
        }
        .padding(.top, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
        .background {
            // Translucent rather than opaque so the gradient reads through and
            // the bar feels like part of the page, not a slab bolted on.
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Palette.surface.opacity(0.5))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Palette.divider)
                        .frame(height: Stroke.hairline)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func item(_ tab: AppTab) -> some View {
        Button {
            if selection == tab {
                onReselect(tab)
            } else {
                selection = tab
            }
        } label: {
            VStack(spacing: Spacing.xxs + 2) {
                Image(systemName: selection == tab ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 19, weight: selection == tab ? .semibold : .regular))
                    .frame(height: 22)

                Text(tab.title)
                    .font(Typography.statLabel)
                    .tracking(0.4)
            }
            .foregroundStyle(selection == tab ? Palette.accentInk : Palette.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.bottom, Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : Motion.gentle, value: selection)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selection == tab ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("App shell") {
    AppShellView()
}

#Preview("Tab bar") {
    @Previewable @State var selection: AppTab = .profile
    return VStack {
        Spacer()
        BenchdTabBar(selection: $selection)
    }
    .gradientBackground()
}
