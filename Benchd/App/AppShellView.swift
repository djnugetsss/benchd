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
struct AppShellView: View {
    @State private var selection: AppTab = .profile

    var body: some View {
        ZStack(alignment: .bottom) {
            GradientBackground()

            TabView(selection: $selection) {
                ForEach(AppTab.allCases) { tab in
                    tabContent(tab)
                        .tag(tab)
                        .toolbar(.hidden, for: .tabBar)
                }
            }

            BenchdTabBar(selection: $selection)
        }
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
            selection = tab
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
