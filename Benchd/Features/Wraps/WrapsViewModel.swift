import SwiftUI

/// Drives the Wraps tab.
@MainActor
@Observable
final class WrapsViewModel {

    enum State: Equatable {
        case loading
        /// Newest first. Never empty in this case — `empty` covers that.
        case ready([WeeklyWrap])
        /// Synced, but no week has been played yet.
        case empty
        case failed(String)
    }

    /// Where a save has got to. Shown under the buttons and cleared on its own.
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var isRefreshing = false
    private(set) var saveState: SaveState = .idle

    /// Which shape the card is shown and exported in.
    var format: WrapFormat = .story

    /// Which week is up on the showpiece. Defaults to the most recent.
    var selectedID: WeeklyWrap.ID?

    let account: SleeperAccount
    private let service: WrapService

    init(account: SleeperAccount, service: WrapService = WrapService()) {
        self.account = account
        self.service = service
    }

    var wraps: [WeeklyWrap] {
        if case .ready(let wraps) = state { return wraps }
        return []
    }

    /// The card on the showpiece.
    var selected: WeeklyWrap? {
        guard let selectedID else { return wraps.first }
        return wraps.first { $0.id == selectedID } ?? wraps.first
    }

    /// Everything that is not currently on the showpiece, in order.
    var history: [WeeklyWrap] {
        guard let selected else { return [] }
        return wraps.filter { $0.id != selected.id }
    }

    // MARK: - Loading

    /// Initial load. Shows skeletons.
    func load() async {
        if wraps.isEmpty { state = .loading }
        await fetch()
    }

    /// Pull to refresh. Keeps whatever is already on screen.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await fetch()
    }

    private func fetch() async {
        do {
            let fetched = try await service.recentWraps(for: account.id)
            if fetched.isEmpty {
                // Only fall back to empty when there is nothing to show. A
                // transient empty read must not wipe a good card off the screen.
                if wraps.isEmpty { state = .empty }
            } else {
                state = .ready(fetched)
                // A week that has scrolled out of the window should not leave
                // the showpiece blank.
                if let selectedID, !fetched.contains(where: { $0.id == selectedID }) {
                    self.selectedID = fetched.first?.id
                }
            }
        } catch let error as WrapError {
            AppLog.wraps.error("wraps load failed: \(error.message, privacy: .public)")
            if wraps.isEmpty { state = .failed(error.message) }
        } catch {
            AppLog.wraps.error("wraps load failed: \(String(describing: error), privacy: .public)")
            if wraps.isEmpty { state = .failed(WrapError.failed("").message) }
        }
    }

    // MARK: - Saving

    /// Renders the card and writes it to the photo library.
    func saveToPhotos(_ wrap: WeeklyWrap, style: WrapCardStyle) async {
        saveState = .saving

        guard let image = WrapExporter.render(wrap, style: style, format: format) else {
            saveState = .failed(WrapExportError.renderFailed.message)
            return clearSaveStateSoon()
        }

        do {
            try await WrapExporter.saveToPhotos(image)
            saveState = .saved
            // The one haptic in the app: the image is now somewhere the person
            // can post it from, and that is worth a tap on the wrist.
            Haptics.confirm()
        } catch let error as WrapExportError {
            saveState = .failed(error.message)
        } catch {
            saveState = .failed(WrapExportError.saveFailed("").message)
        }

        clearSaveStateSoon()
    }

    /// Confirmations are not notifications: this one says its piece and leaves.
    private func clearSaveStateSoon() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self else { return }
            if self.saveState != .saving { self.saveState = .idle }
        }
    }

    // MARK: - Previews

    /// Preview/test seam. Nothing in the app calls this.
    static func preview(
        state: State,
        format: WrapFormat = .story,
        account: SleeperAccount = .sample
    ) -> WrapsViewModel {
        let model = WrapsViewModel(account: account, service: WrapService(client: nil))
        model.state = state
        model.format = format
        return model
    }
}
