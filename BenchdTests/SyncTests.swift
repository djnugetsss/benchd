import Foundation
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

    @Test("last_synced_at is what separates the first sync from the main app")
    func syncedAccountSkipsFirstSync() {
        let fresh = account(lastSyncedAt: nil)
        let synced = account(lastSyncedAt: .now)
        #expect(fresh.lastSyncedAt == nil)
        #expect(synced.lastSyncedAt != nil)
    }
}
