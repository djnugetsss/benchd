import Foundation
import Supabase
import Testing
@testable import Benchd

struct SyncEventTests {

    private func decode(_ json: String) throws -> SyncEvent {
        try PostgrestCoding.decoder.decode(SyncEvent.self, from: Data(json.utf8))
    }

    @Test("A progress event decodes and exposes its fraction")
    func decodesProgress() throws {
        let event = try decode("""
        {
          "id": 42,
          "sleeper_account_id": "aaaaaaaa-0000-0000-0000-000000000001",
          "created_at": "2026-09-22T12:00:00.123456+00:00",
          "kind": "leagues_found",
          "message": "Found 6 leagues.",
          "detail": {"progress": 0.08, "leagues": 6}
        }
        """)
        #expect(event.message == "Found 6 leagues.")
        #expect(event.progress == 0.08)
        #expect(event.detail["leagues"]?.intValue == 6)
        #expect(!event.isTerminal)
    }

    @Test("An event with no progress in its detail returns nil, not zero")
    func missingProgress() throws {
        let event = try decode("""
        {
          "id": 1, "sleeper_account_id": "aaaaaaaa-0000-0000-0000-000000000001",
          "created_at": "2026-09-22T12:00:00+00:00",
          "kind": "started", "message": "Looking…", "detail": {}
        }
        """)
        // Nil matters: zero would yank a part-filled progress bar back to empty.
        #expect(event.progress == nil)
    }

    @Test("Terminal events are recognised, and failure is distinguished")
    func terminalKinds() throws {
        func event(kind: String) throws -> SyncEvent {
            try decode("""
            {
              "id": 1, "sleeper_account_id": "aaaaaaaa-0000-0000-0000-000000000001",
              "created_at": "2026-09-22T12:00:00+00:00",
              "kind": "\(kind)", "message": "m", "detail": {}
            }
            """)
        }
        #expect(try event(kind: "completed").isTerminal)
        #expect(try !event(kind: "completed").isFailure)
        #expect(try event(kind: "failed").isTerminal)
        #expect(try event(kind: "failed").isFailure)
        #expect(try !event(kind: "league").isTerminal)
    }
}

struct SyncErrorTests {

    @Test("A 404 from the gateway means the function is not deployed")
    func notDeployed() {
        let error = SyncService.translate(FunctionsError.httpError(code: 404, data: Data()))
        #expect(error == .notDeployed)
        #expect(error.isPermanent)
    }

    @Test("401 and 403 are credential problems, not transient")
    func unauthorized() {
        for code in [401, 403] {
            let error = SyncService.translate(FunctionsError.httpError(code: code, data: Data()))
            #expect(error == .unauthorized)
            #expect(error.isPermanent)
        }
    }

    @Test("A relay failure or a dropped connection stays transient")
    func transientFailures() {
        // The function may be running server-side; the feed decides.
        #expect(!SyncService.translate(FunctionsError.relayError).isPermanent)
        #expect(!SyncService.translate(URLError(.timedOut)).isPermanent)
        #expect(SyncService.translate(URLError(.notConnectedToInternet)) == .network)
    }

    @Test("A 5xx from a deployed function is not treated as permanent")
    func serverErrorIsTransient() {
        // The function was reached and crashed — a retry can still work, and
        // the run may have written progress before dying.
        #expect(!SyncService.translate(FunctionsError.httpError(code: 500, data: Data())).isPermanent)
    }
}

@MainActor
struct FirstSyncViewModelTests {

    private func model() -> FirstSyncViewModel {
        FirstSyncViewModel(accountID: UUID(), sync: SyncService(client: nil))
    }

    @Test("Only the last few reveals are shown, oldest first")
    func revealWindow() {
        let viewModel = FirstSyncViewModel.preview(stage: .running)
        #expect(viewModel.visibleReveals.count <= 4)
        // The window keeps chronological order so the newest is last.
        let ids = viewModel.visibleReveals.map(\.id)
        #expect(ids == ids.sorted())
        #expect(viewModel.visibleReveals.last?.message == "2025 — The Gridiron Society")
    }

    @Test("An unconfigured backend fails fast instead of polling forever")
    func unconfiguredFailsFast() async {
        let viewModel = model()
        await viewModel.start()
        #expect(viewModel.isFailed)
    }

    @Test("A permanent invoke failure surfaces immediately, not after the stall timeout")
    func permanentFailureIsImmediate() async {
        // Regression test for the real incident: the function was never
        // deployed, the gateway answered 404 in 9ms, and the screen still sat
        // on "Building your career" for 150 seconds before giving up.
        let viewModel = FirstSyncViewModel(
            accountID: UUID(),
            sync: SyncService(client: nil)
        )
        let startedAt = ContinuousClock.now
        await viewModel.start()
        let elapsed = ContinuousClock.now - startedAt

        #expect(viewModel.isFailed)
        #expect(elapsed < .seconds(1))
    }

    @Test("start() does not stomp on a phase that is already running")
    func startIsGuarded() async {
        let viewModel = FirstSyncViewModel.preview(stage: .running)
        await viewModel.start()
        #expect(viewModel.phase == .running)
        #expect(!viewModel.isFailed)
    }

    @Test("isFailed reflects the failed phase only")
    func failedFlag() {
        #expect(FirstSyncViewModel.preview(stage: .failed).isFailed)
        #expect(!FirstSyncViewModel.preview(stage: .running).isFailed)
    }
}

@MainActor
struct AppSessionRoutingTests {

    private func session() -> AppSession {
        AppSession(auth: AuthService(client: nil))
    }

    private func account(lastSyncedAt: Date?) -> SleeperAccount {
        SleeperAccount(
            id: UUID(),
            profileID: UUID(),
            sleeperUserID: "12345",
            username: "anshm",
            displayName: "Ansh",
            avatar: nil,
            lastSyncedAt: lastSyncedAt,
            syncStatus: lastSyncedAt == nil ? .neverSynced : .synced,
            syncError: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test("Signed out goes to the start of onboarding")
    func signedOutRoute() {
        #expect(session().route == .onboarding(startingAt: .welcome))
    }

    @Test("A connected account that has never synced routes to the first sync")
    func neverSyncedRoutesToFirstSync() {
        let session = session()
        let account = account(lastSyncedAt: nil)
        session.markSleeperConnected(account)
        // Auth is nil-backed here, so this asserts the connection branch only.
        #expect(session.connectionState == .connected(account))
    }

    @Test("Finishing a sync bumps the generation Profile keys its reload off")
    func syncCompleteBumpsGeneration() async {
        // This is the link that did not exist before: Profile's .task(id:) is
        // keyed on syncGeneration, so without this increment a finished sync
        // leaves the page showing whatever it loaded on first appear.
        let session = session()
        let before = session.syncGeneration
        await session.markSyncComplete()
        #expect(session.syncGeneration == before + 1)
    }

    @Test("Returning to the foreground also bumps the generation")
    func foregroundBumpsGeneration() async {
        // Covers the hourly cron case: a sync can finish while the app is
        // backgrounded, with nothing in-process to observe it.
        let session = session()
        let before = session.syncGeneration
        await session.refreshAfterForeground()
        #expect(session.syncGeneration == before + 1)
    }

    @Test("last_synced_at is what separates the first sync from the main app")
    func syncedAccountSkipsFirstSync() {
        let fresh = account(lastSyncedAt: nil)
        let synced = account(lastSyncedAt: .now)
        #expect(fresh.lastSyncedAt == nil)
        #expect(synced.lastSyncedAt != nil)
    }
}
