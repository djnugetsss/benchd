import SwiftUI

/// Card shadows: large, diffuse, and nearly invisible.
///
/// The goal is that a surface feels like it is floating a millimetre off the page.
/// If you can point at the shadow, it is too strong. See `docs/DESIGN.md` §6.
enum Elevation {
    /// Standard card.
    case soft
    /// Hero card, sheet, wrap card.
    case lifted

    var color: Color {
        switch self {
        case .soft: Palette.shadow.opacity(0.05)
        case .lifted: Palette.shadow.opacity(0.07)
        }
    }

    var radius: CGFloat {
        switch self {
        case .soft: 20
        case .lifted: 32
        }
    }

    var y: CGFloat {
        switch self {
        case .soft: 6
        case .lifted: 12
        }
    }
}

extension View {
    /// Applies one of the two sanctioned shadows. There is no third option, and
    /// `.shadow(radius:)` should never appear in a feature file.
    func elevation(_ level: Elevation) -> some View {
        shadow(color: level.color, radius: level.radius, x: 0, y: level.y)
    }
}
