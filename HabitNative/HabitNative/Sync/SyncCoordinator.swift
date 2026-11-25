import Foundation

struct SyncPage: Sendable {
    let revisions: [SyncEnvelope]
    let token: Data
    let moreComing: Bool
}

protocol SyncTransport: Sendable {
    func ensureZone(account: String) async throws
    func upload(_ envelope: SyncEnvelope, account: String) async throws
    func fetchPage(account: String, after token: Data?) async throws -> SyncPage
}

/// The transport is invoked only after the user enables sync and an account is bound.
/// App data integration must stage changes atomically with local writes before enabling it.
actor SyncCoordinator {
    enum CoordinatorError: Error { case fetchAlreadyRunning }
    private let store: SyncRevisionStore
    private let transport: any SyncTransport
    private var isFetching = false

    init(store: SyncRevisionStore, transport: any SyncTransport) {
        self.store = store
        self.transport = transport
    }

    func synchronize(account: String) async throws {
        try await fetchRemote(account: account)
        try await uploadPending(account: account)
    }

    /// Fetch and commit remote history before deciding whether local edits
    /// have a shared ancestor. Never uploads data during this phase.
    func fetchRemote(account: String) async throws {
        guard !account.isEmpty else { throw SyncRevisionStore.StoreError.invalidRevision }
        guard !isFetching else { throw CoordinatorError.fetchAlreadyRunning }
        isFetching = true
        defer { isFetching = false }
        try Task.checkCancellation()
        try await transport.ensureZone(account: account)
        var cursor = try store.checkpoint(account: account)
        var more = true
        while more {
            try Task.checkCancellation()
            let page = try await transport.fetchPage(account: account, after: cursor)
            try store.ingestPage(account: account, envelopes: page.revisions, token: page.token)
            cursor = page.token
            more = page.moreComing
        }
    }

    /// Call only after local reconciliation has validated the fetched frontier.
    func uploadPending(account: String) async throws {
        guard !account.isEmpty else { throw SyncRevisionStore.StoreError.invalidRevision }
        for envelope in try store.pending(account: account) {
            try Task.checkCancellation()
            try await transport.upload(envelope, account: account)
            try store.acknowledge(account: account, revisionID: envelope.revision.revisionID)
        }
    }
}
