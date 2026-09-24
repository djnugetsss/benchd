import SwiftUI

/// Settings, reached from the gear on the profile.
///
/// Deliberately not a tab: there are three things worth doing here and none of
/// them is a destination anyone visits twice a week. A fourth tab would spend a
/// permanent quarter of the bottom of the screen on housekeeping.
///
/// Two of the three actions are not wired yet, and they say so rather than being
/// hidden — a settings screen that quietly lacks "disconnect" reads as an app
/// that will not let you leave.
struct SettingsScreen: View {
    @Environment(AppSession.self) private var session
    @State private var isConfirmingSignOut = false
    @State private var isSigningOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                account
                sleeper
                sync
                signOut
                footer
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.md)
            .padding(.bottom, bottomInset)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .gradientBackground()
    }

    /// Clears the custom tab bar, which is still underneath a pushed screen.
    private var bottomInset: CGFloat { Spacing.huge + Spacing.lg }

    // MARK: - Account

    private var account: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Account")

            Card {
                StatRow(
                    title: "Signed in",
                    subtitle: "Email and password",
                    leading: {
                        Image(systemName: "envelope")
                            .font(Typography.button)
                            .foregroundStyle(Palette.textSecondary)
                    },
                    trailing: { EmptyView() }
                )
            }
        }
    }

    // MARK: - Sleeper

    private var sleeper: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Sleeper")

            Card {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    StatRow(
                        title: accountName,
                        subtitle: session.connectedAccount == nil
                            ? "No account connected"
                            : "Connected",
                        leading: {
                            Avatar(
                                name: accountName,
                                imageURL: session.connectedAccount?.avatarURL,
                                size: .small
                            )
                        },
                        trailing: { EmptyView() }
                    )

                    SoftDivider()

                    SecondaryButton("Disconnect", isEnabled: false) {}

                    Text("Disconnecting removes your synced history. Wired up in the next pass.")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var accountName: String {
        guard let account = session.connectedAccount else { return "Not connected" }
        return account.displayName ?? account.username ?? "Your Sleeper account"
    }

    // MARK: - Sync

    private var sync: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Sync")

            Card {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    StatRow(title: "Last synced", subtitle: lastSyncedText) {
                        EmptyView()
                    }

                    SoftDivider()

                    SecondaryButton("Re-sync now", isEnabled: false) {}

                    Text("Benchd already refreshes hourly. Manual pulls are wired up in the next pass.")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var lastSyncedText: String {
        guard let synced = session.connectedAccount?.lastSyncedAt else {
            return "Not yet"
        }
        return synced.formatted(.relative(presentation: .named))
    }

    // MARK: - Sign out

    private var signOut: some View {
        VStack(spacing: Spacing.sm) {
            SecondaryButton(
                isSigningOut ? "Signing out…" : "Sign out",
                systemImage: "rectangle.portrait.and.arrow.right",
                isEnabled: !isSigningOut
            ) {
                isConfirmingSignOut = true
            }
        }
        .confirmationDialog(
            "Sign out of Benchd?",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                isSigningOut = true
                Task { await session.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            // Worth saying: nothing is lost, which is the actual question
            // someone is asking before they tap it.
            Text("Your career stays where it is. Signing back in brings it all back.")
        }
    }

    private var footer: some View {
        Text("Benchd \(appVersion)")
            .font(Typography.caption)
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: .infinity)
    }

    private var appVersion: String {
        let bundle = Bundle.main
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsScreen()
    }
    .environment(AppSession(auth: AuthService(client: nil)))
}
