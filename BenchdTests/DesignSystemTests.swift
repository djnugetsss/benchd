import Testing
@testable import Benchd

struct DesignSystemTests {

    @Test("The spacing scale is strictly increasing")
    func spacingScaleIsOrdered() {
        let scale: [Double] = [
            Spacing.s1, Spacing.s2, Spacing.s3, Spacing.s4, Spacing.s5,
            Spacing.s6, Spacing.s7, Spacing.s8, Spacing.s9,
        ].map(Double.init)

        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
    }

    @Test("Screen margin comes from the scale")
    func screenMarginIsAToken() {
        #expect(Spacing.screenMargin == Spacing.s6)
    }
}
