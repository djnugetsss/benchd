import SwiftUI

/// The shape a wrap card is exported in.
///
/// The sizes are logical points chosen so that rendering at 3x lands exactly on
/// the dimensions Instagram wants — 1080×1920 and 1080×1350 — with no resampling
/// and no off-by-one crop. Everything on a card is laid out against these, which
/// is what makes the exported image identical to the one on screen.
enum WrapFormat: String, CaseIterable, Identifiable, Sendable {
    /// 9:16 — Stories, Reels, and anywhere full-screen.
    case story
    /// 4:5 — the tallest a feed post is allowed to be, so it takes the most room
    /// in a scroll.
    case post

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .story: CGSize(width: 360, height: 640)
        case .post: CGSize(width: 360, height: 450)
        }
    }

    /// What the toggle calls it.
    var label: String {
        switch self {
        case .story: "Story"
        case .post: "Post"
        }
    }

    /// The ratio as people describe it, for the toggle's subtitle.
    var ratioText: String {
        switch self {
        case .story: "9:16"
        case .post: "4:5"
        }
    }

    var aspectRatio: CGFloat { size.width / size.height }

    /// How tall the card stands on the Wraps tab.
    ///
    /// Not a design token: it is the height that leaves the whole card, the
    /// format toggle and the share button on screen together on a current phone.
    /// A showpiece you have to scroll to see is not a showpiece, and a share
    /// button below the fold is a share that does not happen.
    var showpieceHeight: CGFloat {
        switch self {
        case .story: 470
        case .post: 424
        }
    }

    /// A story has 190 more points of height to spend; a post has to hold the
    /// same content in less room, so it breathes less.
    var padding: CGFloat {
        switch self {
        case .story: Spacing.xl
        case .post: Spacing.lg
        }
    }
}

/// The three layouts, so one week can be told three ways.
///
/// They differ in what leads, not in decoration: a card whose variations are the
/// same layout in three colours is one layout.
enum WrapCardStyle: String, CaseIterable, Identifiable, Sendable {
    /// Hero-number led. The week's score, then the lineup that produced it.
    case scoreline
    /// List led. The three performers are the card, ranked down the page.
    case podium
    /// Magazine cover. One statement, one number, and a great deal of air.
    case cover

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scoreline: "Scoreline"
        case .podium: "Podium"
        case .cover: "Cover"
        }
    }
}
