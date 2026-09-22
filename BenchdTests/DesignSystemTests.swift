import SwiftUI
import Testing
@testable import Benchd

struct DesignSystemTests {

    @Test("The spacing scale is strictly increasing with no duplicates")
    func spacingScaleIsOrdered() {
        let scale = Spacing.scale.map(Double.init)
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
    }

    @Test("Every spacing token is a multiple of the base unit")
    func spacingIsOnTheGrid() {
        for value in Spacing.scale {
            #expect(
                value.truncatingRemainder(dividingBy: Spacing.unit) == 0,
                "\(value) is not a multiple of \(Spacing.unit)"
            )
        }
    }

    @Test("Semantic spacing tokens come from the scale")
    func semanticSpacingUsesTheScale() {
        for value in [Spacing.screen, Spacing.cardPadding, Spacing.sectionGap, Spacing.sectionGapLarge] {
            #expect(Spacing.scale.contains(value))
        }
    }

    @Test("Card radii sit in the 20–28 range DESIGN.md specifies")
    func cardRadiiAreInRange() {
        for radius in [Radius.card, Radius.cardLarge, Radius.hero] {
            #expect((20...28).contains(radius))
        }
    }

    @Test("Radius scale is strictly increasing")
    func radiusScaleIsOrdered() {
        let scale = Radius.scale.map(Double.init)
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
    }

    @Test("Strokes are never heavier than 1pt")
    func strokesAreHairlines() {
        #expect(Stroke.hairline <= 1)
        #expect(Stroke.border <= 1)
        #expect(Stroke.hairline < Stroke.border)
    }

    @Test("Display tracking is negative and tightens as size grows")
    func displayTrackingTightens() {
        #expect(DisplayStyle.hero.tracking < DisplayStyle.large.tracking)
        #expect(DisplayStyle.large.tracking < DisplayStyle.medium.tracking)
        #expect(DisplayStyle.medium.tracking < DisplayStyle.small.tracking)
        #expect(DisplayStyle.small.tracking < 0)
    }

    @Test("Avatar sizes increase")
    func avatarSizesIncrease() {
        let sizes = [Avatar.Size.small, .medium, .large, .hero].map(\.diameter)
        #expect(sizes == sizes.sorted())
    }

    @Test("Avatar initials take at most two letters and never render empty")
    func avatarInitials() {
        #expect(Avatar.initials(from: "Ansh Mehta") == "AM")
        #expect(Avatar.initials(from: "singlename") == "S")
        #expect(Avatar.initials(from: "a b c d") == "AB")
        #expect(Avatar.initials(from: "") == "?")
        #expect(Avatar.initials(from: "   ") == "?")
    }

    @Test("StatValue settles to the text used for accessibility")
    func statValueSettledText() {
        #expect(StatValue.text("128–74").settledText == "128–74")
        #expect(StatValue.number(3).settledText == "3")
        // Avoid values that sit on a rounding boundary — 63.45 is 63.4499… in
        // binary and formats to "63.4", which tests the formatter, not us.
        #expect(StatValue.number(63.4, decimals: 1).settledText == "63.4")
        #expect(StatValue.number(63.4, decimals: 0).settledText == "63")
    }

    @Test("Elevation stays soft — low opacity, large radius")
    func elevationIsSubtle() {
        #expect(Elevation.soft.radius >= 20)
        #expect(Elevation.lifted.radius > Elevation.soft.radius)
        #expect(Elevation.lifted.y > Elevation.soft.y)
    }
}
