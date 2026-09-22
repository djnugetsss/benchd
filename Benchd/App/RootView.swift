import SwiftUI

/// The app's root.
///
/// - TODO: **TEMPORARY — REMOVE BEFORE WIRING AUTH/ONBOARDING ROUTING.**
///   The root is pinned to `DesignGalleryView` so the design system can be
///   reviewed on device. When real routing lands, this becomes the
///   onboarding/authenticated switch and `PlaceholderScreen` is deleted outright.
///   Restore with: `PlaceholderScreen()` — or go straight to the real router.
struct RootView: View {
    var body: some View {
        DesignGalleryView()
    }
}

#Preview("Root — design gallery (temporary)") {
    RootView()
}

#Preview("Placeholder (what root will replace)") {
    PlaceholderScreen()
}
