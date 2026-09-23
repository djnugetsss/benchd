import Foundation

/// Loads the career profile for a connected Sleeper account.
@Observable
final class ProfileViewModel {

    enum State: Equatable {
        case loading
        case ready(CareerStats)
        /// Connected, but no stats row yet — the first sync has not produced one.
        case awaitingFirstSync
        case failed(String)
    }

    private(set) var state: State = .loading
    /// Separate from `.loading` so a pull-to-refresh does not blank the screen
    /// back to skeletons over data that is already on it.
    private(set) var isRefreshing = false

    let account: SleeperAccount
    private let service: CareerStatsService

    init(account: SleeperAccount, service: CareerStatsService = CareerStatsService()) {
        self.account = account
        self.service = service
    }

    var stats: CareerStats? {
        if case .ready(let stats) = state { return stats }
        return nil
    }

    /// Initial load. Shows skeletons.
    func load() async {
        if stats == nil { state = .loading }
        await fetch()
    }

    /// Manual or triggered refresh. Keeps whatever is already on screen.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await fetch()
    }

    private func fetch() async {
        do {
            let fetched = try await service.stats(for: account.id)
            if let fetched {
                state = .ready(fetched)
            } else if stats == nil {
                // Only fall back to the waiting state when there is nothing to
                // show. A transient empty read should not wipe good data.
                state = .awaitingFirstSync
            }
        } catch let error as CareerStatsError {
            AppLog.profile.error("profile load failed: \(error.message, privacy: .public)")
            if stats == nil { state = .failed(error.message) }
        } catch {
            AppLog.profile.error("profile load failed: \(String(describing: error), privacy: .public)")
            if stats == nil { state = .failed("We couldn't load your career just now.") }
        }
    }

    /// Preview/test seam. Nothing in the app calls this.
    static func preview(state: State, account: SleeperAccount = .sample) -> ProfileViewModel {
        let model = ProfileViewModel(account: account, service: CareerStatsService(client: nil))
        model.state = state
        return model
    }
}
