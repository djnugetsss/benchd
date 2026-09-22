import SwiftUI

/// Renders every token and component in the design system, plus a sample
/// composition showing how they come together.
///
/// This is the visual regression check for `docs/DESIGN.md` — open it after
/// changing anything in `DesignSystem/`. It is a development surface, not a
/// product screen, so it is the one place where a plain scrolling list of
/// specimens is the right answer.
struct DesignGalleryView: View {
    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sectionGapLarge) {
                    header
                    sampleComposition
                    colorSection
                    typographySection
                    spacingSection
                    shapeSection
                    componentSection
                    loadingSection
                    emptySection
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.huge)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Design System").titleStyle()
            Text("Every token and component in Benchd.")
                .font(Typography.callout)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    // MARK: - Sample composition
    //
    // The thing the whole system exists to produce: one focal number, supporting
    // stats a clear step quieter, exactly one accent, and a lot of air.

    private var sampleComposition: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            specimenLabel("Sample composition — career card")

            Card(padding: Spacing.lg, radius: Radius.hero, elevation: .lifted) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(spacing: Spacing.sm) {
                        Avatar(name: "Ansh Mehta", size: .medium)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ansh Mehta")
                                .font(Typography.headline)
                                .foregroundStyle(Palette.textPrimary)
                            Text("@anshm · 6 seasons")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.textTertiary)
                        }

                        Spacer(minLength: 0)
                        PillTag("Active", tone: .accent)
                    }

                    StatBlock(
                        label: "All-time record",
                        value: .text("128–74"),
                        style: .hero,
                        caption: "63.4% win rate"
                    )
                    .padding(.vertical, Spacing.xs)

                    SoftDivider()

                    HStack(alignment: .top, spacing: Spacing.md) {
                        StatBlock(label: "Titles", value: .number(3), style: .medium)
                        StatBlock(label: "Playoffs", value: .number(5), style: .medium)
                        StatBlock(
                            label: "Best finish",
                            value: .text("1st"),
                            style: .medium
                        )
                    }
                }
            }
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Color", subtitle: "Palette.swift is the only file with raw values")

            swatchRow("Base", [
                ("gradientTop", Palette.gradientTop),
                ("gradientBottom", Palette.gradientBottom),
                ("surface", Palette.surface),
                ("surfaceSecondary", Palette.surfaceSecondary),
                ("divider", Palette.divider),
            ])

            swatchRow("Text", [
                ("textPrimary", Palette.textPrimary),
                ("textSecondary", Palette.textSecondary),
                ("textTertiary", Palette.textTertiary),
            ])

            swatchRow("Accent", [
                ("accent", Palette.accent),
                ("accentInk", Palette.accentInk),
                ("accentTint", Palette.accentTint),
            ])

            swatchRow("Semantic (restricted)", [
                ("positive", Palette.positive),
                ("negative", Palette.negative),
            ])

            Card {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("accent never carries text")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    HStack(spacing: Spacing.md) {
                        Text("2.2:1").displayStyle(.small).foregroundStyle(Palette.accent)
                        Text("5.1:1").displayStyle(.small).foregroundStyle(Palette.accentInk)
                    }
                }
            }
        }
    }

    private func swatchRow(_ title: String, _ colors: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).statLabelStyle()

            HStack(spacing: Spacing.xs) {
                ForEach(colors, id: \.0) { name, color in
                    VStack(spacing: Spacing.xxs) {
                        RoundedRectangle.soft(Radius.sm)
                            .fill(color)
                            .frame(height: 52)
                            .overlay(
                                RoundedRectangle.soft(Radius.sm)
                                    .strokeBorder(Palette.divider, lineWidth: Stroke.hairline)
                            )
                        Text(name)
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }

    // MARK: - Typography

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Typography", subtitle: "SF Pro — display light and tight, text normal")

            Card {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(DisplayStyle.allCases, id: \.name) { style in
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(style.name).statLabelStyle()
                            Text("128.4")
                                .displayStyle(style)
                                .foregroundStyle(Palette.textPrimary)
                        }
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    specimen("title", Typography.title, Palette.textPrimary)
                    specimen("headline", Typography.headline, Palette.textPrimary)
                    specimen("body", Typography.body, Palette.textPrimary)
                    specimen("callout", Typography.callout, Palette.textSecondary)
                    specimen("caption", Typography.caption, Palette.textTertiary)
                    specimen("button", Typography.button, Palette.textPrimary)

                    SoftDivider().padding(.vertical, Spacing.xxs)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("statLabel").statLabelStyle()
                        Text("All-time record").statLabelStyle()
                    }
                }
            }
        }
    }

    private func specimen(_ name: String, _ font: Font, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(name)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 62, alignment: .leading)
            Text("The quiet season")
                .font(font)
                .foregroundStyle(color)
        }
    }

    // MARK: - Spacing

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Spacing", subtitle: "Base unit 4 — when in doubt, go up a step")

            Card {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(Spacing.scale, id: \.self) { value in
                        HStack(spacing: Spacing.sm) {
                            Text("\(Int(value))")
                                .font(Typography.caption)
                                .monospacedDigit()
                                .foregroundStyle(Palette.textTertiary)
                                .frame(width: 24, alignment: .trailing)
                            RoundedRectangle.soft(3)
                                .fill(Palette.accentTint)
                                .frame(width: value, height: 10)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shape and depth

    private var shapeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Shape & depth", subtitle: "Continuous corners, near-invisible shadows")

            HStack(spacing: Spacing.xs) {
                ForEach(Radius.scale, id: \.self) { radius in
                    VStack(spacing: Spacing.xxs) {
                        RoundedRectangle.soft(radius)
                            .fill(Palette.surface)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle.soft(radius)
                                    .strokeBorder(Palette.divider, lineWidth: Stroke.border)
                            )
                            .elevation(.soft)
                        Text("\(Int(radius))")
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }

            HStack(spacing: Spacing.md) {
                depthSpecimen("soft", .soft)
                depthSpecimen("lifted", .lifted)
            }
        }
    }

    private func depthSpecimen(_ name: String, _ level: Elevation) -> some View {
        VStack(spacing: Spacing.xs) {
            RoundedRectangle.soft(Radius.card)
                .fill(Palette.surface)
                .frame(height: 72)
                .overlay(
                    RoundedRectangle.soft(Radius.card)
                        .strokeBorder(Palette.divider, lineWidth: Stroke.border)
                )
                .elevation(level)
            Text(name).statLabelStyle()
        }
    }

    // MARK: - Components

    private var componentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Components")

            specimenLabel("StatBlock")
            Card {
                HStack(alignment: .top, spacing: Spacing.md) {
                    StatBlock(label: "Points", value: .number(1842.6, decimals: 1), style: .medium)
                    StatBlock(label: "Rank", value: .text("2nd"), style: .medium)
                    StatBlock(label: "Streak", value: .number(4), style: .medium, accented: true)
                }
            }

            specimenLabel("PillTag")
            HStack(spacing: Spacing.xs) {
                PillTag("QB")
                PillTag("2024")
                PillTag("Active", tone: .accent)
                PillTag("Questionable", systemImage: "cross.case")
                Spacer(minLength: 0)
            }

            specimenLabel("Avatar")
            HStack(spacing: Spacing.md) {
                Avatar(name: "Ansh Mehta", size: .small)
                Avatar(name: "Ansh Mehta", size: .medium)
                Avatar(name: "Ansh Mehta", size: .large)
                Avatar(name: "Ansh Mehta", size: .large, showsRing: true)
                Spacer(minLength: 0)
            }

            specimenLabel("Buttons")
            VStack(spacing: Spacing.sm) {
                PrimaryButton("Connect Sleeper") {}
                PrimaryButton("Share your wrap", tone: .accent, systemImage: "square.and.arrow.up") {}
                SecondaryButton("Not now") {}
                PrimaryButton("Disabled", isEnabled: false) {}
            }

            specimenLabel("SoftDivider")
            Card {
                VStack(spacing: Spacing.sm) {
                    Text("Above").font(Typography.body).foregroundStyle(Palette.textSecondary)
                    SoftDivider()
                    Text("Below").font(Typography.body).foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Loading", subtitle: "Sketch the shape of the screen, never a spinner")

            Card {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonBlock(width: 90, height: 11)
                    SkeletonBlock(width: 160, height: 44)
                    SkeletonBlock(height: 11)
                    SkeletonBlock(width: 200, height: 11)
                }
            }
        }
    }

    // MARK: - Empty

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Empty state")

            Card {
                EmptyState(
                    title: "No leagues yet",
                    message: "Connect your Sleeper account and we'll build your career profile from it.",
                    systemImage: "person.crop.circle"
                ) {
                    SecondaryButton("Connect Sleeper") {}
                        .frame(maxWidth: 220)
                }
            }
        }
    }

    // MARK: - Helpers

    private func specimenLabel(_ text: String) -> some View {
        Text(text).statLabelStyle()
    }
}

#Preview {
    DesignGalleryView()
}
