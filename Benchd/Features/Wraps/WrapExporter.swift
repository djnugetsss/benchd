import CoreTransferable
import Photos
import SwiftUI
import UniformTypeIdentifiers

/// Turns a wrap card into an image, and puts it somewhere.
///
/// The card is laid out at a fixed point size and rendered at 3x, so a story
/// lands on exactly 1080×1920 and a post on 1080×1350 — the sizes Instagram
/// stores. Rendering at the device's own scale would produce 1170-wide images on
/// one phone and 1284 on another, both of which get resampled on upload, and
/// resampling is what makes light type on a light background look muddy.
@MainActor
enum WrapExporter {

    /// 3x turns the 360-point canvas into a 1080-pixel image. Not the device
    /// scale: the export must not depend on which phone it ran on.
    static let renderScale: CGFloat = 3

    /// Renders the card. `nil` only if the renderer fails outright, which in
    /// practice means the process is out of memory.
    static func render(
        _ wrap: WeeklyWrap,
        style: WrapCardStyle,
        format: WrapFormat
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: WrapCardView(wrap: wrap, style: style, format: format)
        )
        renderer.scale = renderScale
        // No alpha channel. The card is full-bleed, and a transparent PNG picks
        // up a black background the moment something flattens it.
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// A rendered card, ready for the share sheet.
    static func shareable(
        _ wrap: WeeklyWrap,
        style: WrapCardStyle,
        format: WrapFormat
    ) -> WrapImage? {
        guard let image = render(wrap, style: style, format: format) else { return nil }
        return WrapImage(image: image, wrap: wrap, format: format)
    }

    /// Writes the card to the photo library.
    ///
    /// Add-only authorization: Benchd writes one image and never reads the
    /// library, and asking for full access to do that is how an app teaches
    /// people to say no. `.limited` counts as granted here — for an add-only
    /// request it means the same thing.
    static func saveToPhotos(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw WrapExportError.photosDenied
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            throw WrapExportError.saveFailed(error.localizedDescription)
        }
    }
}

// MARK: - The transferable image

/// A rendered card on its way out of the app.
///
/// Exported as PNG rather than as a SwiftUI `Image` so the bytes are known: PNG
/// is lossless, and JPEG artefacts around 64-point light type on a near-white
/// background are exactly the kind of cheap that this card cannot afford.
struct WrapImage: Transferable, Sendable {
    let image: UIImage
    let wrap: WeeklyWrap
    let format: WrapFormat

    /// "Benchd-Week-5-2026.png" — what it is called once it is saved.
    var filename: String { "Benchd-Week-\(wrap.week)-\(wrap.season).png" }

    /// What the share sheet shows above the app list.
    var title: String {
        if let highlight = wrap.highlight {
            return "Week \(wrap.week) · \(highlight.headline)"
        }
        return "Week \(wrap.week) · \(wrap.recordText)"
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { wrapImage in
            guard let data = wrapImage.image.pngData() else {
                throw WrapExportError.renderFailed
            }
            return data
        }
        .suggestedFileName { $0.filename }
    }
}

// MARK: - Errors

enum WrapExportError: Error, Equatable, Sendable {
    case renderFailed
    case photosDenied
    case saveFailed(String)

    /// Written for someone who just tapped Save, not for a log.
    var message: String {
        switch self {
        case .renderFailed:
            "We couldn't make the image just now."
        case .photosDenied:
            "Benchd needs permission to add photos. You can turn it on in Settings."
        case .saveFailed:
            "We couldn't save to Photos just now."
        }
    }
}
