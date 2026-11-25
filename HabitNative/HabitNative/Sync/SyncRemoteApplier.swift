import Foundation

/// Bridges downloaded revisions to the app database using a durable,
/// per-account last-applied baseline.
@MainActor
final class SyncRemoteApplier {
    enum SyncError: Error { case alreadyRunning }
    private let coordinator: SyncCoordinator
    private let store: SyncRevisionStore
    private let database: NativeDatabase
    private var isSynchronizing = false

    init(coordinator: SyncCoordinator, store: SyncRevisionStore, database: NativeDatabase) {
        self.coordinator = coordinator
        self.store = store
        self.database = database
    }

    /// The database layer checks its snapshot again inside the write transaction.
    /// Conflicts, unknown namespaces, and malformed values abort the whole batch.
    func fetchAndApply(account: String) async throws {
        try SyncSnapshotBootstrap(database: database).bindAccount(account)
        try await coordinator.fetchRemote(account: account)
        try Task.checkCancellation()
        let frontiers = try store.frontiers(account: account)
        guard frontiers.keys.allSatisfy({ $0.hasPrefix("db/") }) else {
            throw SyncSnapshotBootstrap.BootstrapError.invalidData
        }
        let snapshot = try SyncSnapshotReader(database: database).read()
        let bootstrap = SyncSnapshotBootstrap(database: database)
        let saved = try bootstrap.readBaseline(account: account)
        var baseline = saved?.values ?? [:]
        var baselineRevisionIDs = saved?.revisionIDs ?? [:]
        // A crash can leave a staged local revision in the journal before its
        // baseline reaches the app database. Accept it only when every step
        // back to the saved ancestor has a persisted local lineage.
        for (key, revisions) in frontiers where revisions.count == 1 {
            let head = revisions[0]
            guard try store.isLocal(account: account, revisionID: head.revisionID),
                  try store.hasLocalLineage(account: account, revisionID: head.revisionID, since: baselineRevisionIDs[key]) else { continue }
            baseline[key] = head.value
            baselineRevisionIDs[key] = head.revisionID
        }
        try bootstrap.applyRemoteBatch(
            expected: snapshot, lastApplied: baseline, baselineRevisionIDs: baselineRevisionIDs, frontiers: frontiers, account: account)
    }

    /// Reconcile before staging or uploading. The journal and applied baseline
    /// are durable, so another cycle can recover from an interruption.
    func synchronizeDatabase(account: String, device: String) async throws {
        guard !device.isEmpty else { throw SyncRevisionStore.StoreError.invalidRevision }
        guard !isSynchronizing else { throw SyncError.alreadyRunning }
        isSynchronizing = true
        defer { isSynchronizing = false }
        try await fetchAndApply(account: account)
        let bootstrap = SyncSnapshotBootstrap(database: database)
        try bootstrap.bindAccount(account)
        let baseline = try bootstrap.readBaseline(account: account)
        let previous = (baseline?.values ?? [:]).map { SyncDesiredValue(entityKey: $0.key, data: $0.value) }
        let snapshot = try SyncSnapshotReader(database: database).read()
        let current = try SyncChangePlanner.desiredDatabaseValues(snapshot)
        let frontiers = try store.frontiers(account: account)
        let changes = try SyncChangePlanner.prepareLocalBatch(previous: previous, current: current,
            baselineRevisionIDs: baseline?.revisionIDs ?? [:], frontiers: frontiers)
        if !changes.isEmpty {
            _ = try store.stageBatch(account: account, device: device, changes: changes)
        }
        // Fetch again before upload to expose changes from another device.
        try await fetchAndApply(account: account)
        // A local clear can occur while the network fetch is in flight. Check
        // its transactional pause marker again before sending queued changes.
        try bootstrap.bindAccount(account)
        try await coordinator.uploadPending(account: account)
    }
}
