import CloudKit
import Combine
import Foundation

/// Owns the user-visible iCloud sync lifecycle. Sync is opt-in and only runs
/// for an active paid membership; no local data is sent before both gates pass.
@MainActor
final class ICloudSyncManager: ObservableObject {
    static let shared = ICloudSyncManager()
    static let dataChanged = Notification.Name("HabitICloudSyncDataChanged")

    enum State: Equatable {
        case off
        case idle
        case syncing
        case needsAttention
        case unavailable
    }

    @Published private(set) var state: State = .off
    @Published private(set) var detail = ""

    private static let enabledKey = "icloud.sync.enabled.v1"
    private static let deviceKey = "icloud.sync.device-id.v1"
    private let defaults: UserDefaults
    private let database: NativeDatabase
    private var transport: SyncCloudTransport?
    private var applier: SyncRemoteApplier?
    private var setupError: Error?
    private var syncTask: Task<Void, Never>?

    var isEnabled: Bool { defaults.bool(forKey: Self.enabledKey) }

    private init(defaults: UserDefaults = .standard, database: NativeDatabase? = nil) {
        self.defaults = defaults
        self.database = database ?? NativeDatabase()
    }

    private func ensureSyncEngine() throws -> (SyncCloudTransport, SyncRemoteApplier) {
        if let transport = self.transport, let applier = self.applier {
            return (transport, applier)
        }
        if let setupError = self.setupError {
            throw setupError
        }
        do {
            let storeURL = database.fileURL.deletingLastPathComponent().appendingPathComponent("icloud_sync_journal.sqlite")
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let transport = SyncCloudTransport(container: CKContainer.default())
            let store = try SyncRevisionStore(url: storeURL)
            let coordinator = SyncCoordinator(store: store, transport: transport)
            let applier = SyncRemoteApplier(coordinator: coordinator, store: store, database: database)
            self.transport = transport
            self.applier = applier
            return (transport, applier)
        } catch {
            self.setupError = error
            throw error
        }
    }

    func setEnabled(_ enabled: Bool, membership: SubscriptionTier) {
        guard enabled else {
            defaults.set(false, forKey: Self.enabledKey)
            syncTask?.cancel()
            state = .off
            detail = ""
            return
        }
        guard membership.hasSyncAccess else {
            defaults.set(false, forKey: Self.enabledKey)
            state = .unavailable
            detail = AppLanguage.text("sync.membershipRequired")
            return
        }
        defaults.set(true, forKey: Self.enabledKey)
        requestSync(membership: membership)
    }

    func requestSync(membership: SubscriptionTier) {
        guard isEnabled else { state = .off; return }
        guard membership.hasSyncAccess else {
            state = .unavailable
            detail = AppLanguage.text("sync.membershipRestored")
            return
        }
        guard syncTask == nil else { return }
        state = .syncing
        detail = AppLanguage.text("sync.syncing")
        syncTask = Task { [weak self] in
            guard let self else { return }
            defer { self.syncTask = nil }
            do {
                let (transport, applier) = try self.ensureSyncEngine()
                let account = try await transport.currentAccountID()
                try await applier.synchronizeDatabase(account: account, device: self.deviceID())
                guard !Task.isCancelled else { return }
                self.state = .idle
                self.detail = AppLanguage.text("sync.complete")
                NotificationCenter.default.post(name: Self.dataChanged, object: nil)
            } catch is CancellationError {
                self.state = self.isEnabled ? .idle : .off
            } catch let error as SyncSnapshotBootstrap.BootstrapError {
                self.handleBootstrapError(error)
            } catch let error as SyncCloudTransport.TransportError {
                self.handleTransportError(error)
            } catch {
                self.state = .unavailable
                self.detail = AppLanguage.text("sync.unavailable")
            }
        }
    }

    private func deviceID() -> String {
        if let id = defaults.string(forKey: Self.deviceKey), UUID(uuidString: id) != nil { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Self.deviceKey)
        return id
    }

    private func handleBootstrapError(_ error: SyncSnapshotBootstrap.BootstrapError) {
        state = .needsAttention
        switch error {
        case .localDataCleared:
            detail = AppLanguage.text("sync.localClearPaused")
        case .accountChanged:
            detail = AppLanguage.text("sync.accountChanged")
        case .conflict:
            detail = AppLanguage.text("sync.conflict")
        case .localDataPresent:
            detail = AppLanguage.text("sync.localDataPresent")
        default:
            detail = AppLanguage.text("sync.checkNeeded")
        }
    }

    private func handleTransportError(_ error: SyncCloudTransport.TransportError) {
        state = .unavailable
        switch error {
        case .signedOut:
            detail = AppLanguage.text("sync.signIn")
        case .accountChanged:
            detail = AppLanguage.text("sync.accountChanged")
        default:
            detail = AppLanguage.text("sync.unavailable")
        }
    }
}
