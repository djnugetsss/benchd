import Foundation

/// Drives the first-sync screen: starts the sync, then polls its progress feed.
@Observable
final class FirstSyncViewModel {

    enum Phase: Equatable {
        case starting
        case running
        case finished
        case failed(String)
    }

    private(set) var phase: Phase = .starting
    /// Newest last. The screen shows a window of the most recent few.
    private(set) var reveals: [SyncEvent] = []
    private(set) var progress: Double = 0

    private let accountID: UUID
    private let sync: SyncService
    private let onFinished: () -> Void

    private var lastEventID: Int = 0
    private var pollTask: Task<Void, Never>?

    /// Fast enough that reveals feel live, slow enough that a two-minute sync is
    /// ~80 requests rather than a thousand.
    private static let pollInterval = Duration.milliseconds(1500)

    /// If the feed goes quiet for this long with no terminal event, something
    /// died server-side. Without this the screen would wait forever.
    private static let stallTimeout: Duration = .seconds(150)

    init(
        accountID: UUID,
        sync: SyncService = SyncService(),
        onFinished: @escaping () -> Void = {}
    ) {
        self.accountID = accountID
        self.sync = sync
        self.onFinished = onFinished
    }

    /// The last few reveals, oldest first. Older ones fade rather than scroll.
    var visibleReveals: [SyncEvent] {
        Array(reveals.suffix(4))
    }

    var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    func start() async {
        // `.starting` is the only state a run may begin from. Guards both a
        // double-start and a preview that has already staged a phase.
        guard pollTask == nil, phase == .starting else { return }
        phase = .starting
        progress = 0

        do {
            try await sync.start(accountID: accountID)
        } catch let error as SyncError {
            // A timeout on the invoke is not a failed sync — the function keeps
            // running server-side. Only a definite refusal stops us; otherwise
            // fall through to polling, which is the real source of truth.
            if case .notConfigured = error {
                phase = .failed(error.message)
                return
            }
        } catch {
            // Same reasoning: let the feed decide.
        }

        phase = .running
        pollTask = Task { [weak self] in await self?.poll() }
    }

    func cancel() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Retry after a failure. The sync is idempotent, so re-running is safe.
    func retry() async {
        cancel()
        reveals = []
        lastEventID = 0
        progress = 0
        await start()
    }

    private func poll() async {
        var lastChangeAt = ContinuousClock.now

        while !Task.isCancelled {
            do {
                let newEvents = try await sync.events(for: accountID, after: lastEventID)

                if !newEvents.isEmpty {
                    lastChangeAt = ContinuousClock.now
                    lastEventID = newEvents.last?.id ?? lastEventID
                    reveals.append(contentsOf: newEvents)

                    if let latest = newEvents.compactMap(\.progress).last {
                        progress = latest
                    }

                    if let terminal = newEvents.first(where: \.isTerminal) {
                        finish(with: terminal)
                        return
                    }
                }

                if ContinuousClock.now - lastChangeAt > Self.stallTimeout {
                    phase = .failed("The sync stopped responding. Try again.")
                    return
                }
            } catch {
                // A dropped poll is not a failure — the network may blip while
                // the function keeps working. The stall timeout is the backstop.
            }

            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    /// Preview seam: fills in a plausible feed without a backend. Nothing in
    /// the app calls this.
    func applyPreview(_ stage: FirstSyncViewModel.PreviewStage) {
        let messages = [
            "Found 6 leagues.",
            "Going back to 2019.",
            "2026 — Dynasty Warriors",
            "2025 — The Gridiron Society",
        ]
        reveals = messages.enumerated().map { index, message in
            SyncEvent(
                id: index + 1,
                sleeperAccountID: UUID(),
                createdAt: .now,
                kind: "league",
                message: message,
                detail: .object(["progress": .number(Double(index + 1) / 6)])
            )
        }
        progress = 0.62
        switch stage {
        case .running:
            phase = .running
        case .failed:
            phase = .failed("Sleeper isn't responding right now. Try again in a moment.")
        }
    }

    private func finish(with event: SyncEvent) {
        pollTask = nil
        if event.isFailure {
            phase = .failed(event.message)
        } else {
            progress = 1
            phase = .finished
            onFinished()
        }
    }
}
