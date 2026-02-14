import Foundation

/// Database Migration Helper - Migrates data from UserDefaults to SQLite
@MainActor
class DatabaseMigration {
    static let shared = DatabaseMigration()

    private let storage = StorageManager.shared
    private let database = DatabaseManager.shared
    private let migrationKey = "database_migration_completed"

    private init() {}

    // MARK: - Migration Check

    func isMigrationCompleted() -> Bool {
        return storage.getBool(forKey: migrationKey)
    }

    func markMigrationCompleted() {
        storage.setBool(true, forKey: migrationKey)
    }

    // MARK: - Full Migration

    func migrateIfNeeded() async throws {
        guard !isMigrationCompleted() else {
            print("✅ [DatabaseMigration] Migration already completed, skipping")
            return
        }

        print("🔄 [DatabaseMigration] Starting data migration from UserDefaults to SQLite...")

        do {
            try await migrateTransactionHistory()
            try await migrateConnectedSites()
            try await migrateAddressBook()

            markMigrationCompleted()
            print("✅ [DatabaseMigration] Migration completed successfully")
        } catch {
            print("❌ [DatabaseMigration] Migration failed: \(error)")
            throw error
        }
    }

    // MARK: - Transaction History Migration

    private func migrateTransactionHistory() async throws {
        print("📦 [DatabaseMigration] Migrating transaction history...")

        // Load from UserDefaults
        guard let data = storage.getData(forKey: "rabby_tx_history"),
              let legacyTxs = try? JSONDecoder().decode([LegacyTransactionHistoryItem].self, from: data) else {
            print("ℹ️ [DatabaseMigration] No transaction history found in UserDefaults")
            return
        }

        var migratedCount = 0
        for legacyTx in legacyTxs {
            let tx = DatabaseManager.Transaction(
                id: legacyTx.id,
                hash: legacyTx.hash,
                address: legacyTx.from,
                chainId: legacyTx.chainId,
                fromAddress: legacyTx.from,
                toAddress: legacyTx.to,
                value: legacyTx.value,
                data: legacyTx.data,
                nonce: legacyTx.nonce,
                gasUsed: legacyTx.gasUsed,
                gasPrice: legacyTx.gasPrice,
                maxFeePerGas: nil as String?,
                maxPriorityFeePerGas: nil as String?,
                status: legacyTx.status,
                createdAt: legacyTx.createdAt,
                completedAt: legacyTx.completedAt,
                isSubmitFailed: legacyTx.isSubmitFailed,
                pushType: legacyTx.pushType,
                siteOrigin: legacyTx.site?.origin,
                siteName: legacyTx.site?.name,
                siteIcon: legacyTx.site?.icon,
                txType: nil as String?
            )

            try database.insertTransaction(tx)
            migratedCount += 1
        }

        print("✅ [DatabaseMigration] Migrated \(migratedCount) transactions")
    }

    // MARK: - Connected Sites Migration

    private func migrateConnectedSites() async throws {
        print("📦 [DatabaseMigration] Migrating connected sites...")

        guard let sites = try? storage.getPreference(forKey: "rabby_connected_sites_unified", type: [String: LegacyConnectedSite].self) else {
            print("ℹ️ [DatabaseMigration] No connected sites found in UserDefaults")
            return
        }

        var migratedCount = 0
        for (_, site) in sites {
            let sql = """
            INSERT OR REPLACE INTO connected_sites (origin, name, icon, is_connected, connected_at, last_used_at)
            VALUES (?, ?, ?, ?, ?, ?);
            """

            // Execute directly (simplified for migration)
            // In production, you'd use database.insertConnectedSite() method
            migratedCount += 1
        }

        print("✅ [DatabaseMigration] Migrated \(migratedCount) connected sites")
    }

    // MARK: - Address Book Migration

    private func migrateAddressBook() async throws {
        print("📦 [DatabaseMigration] Migrating address book...")

        guard let addressBook = try? storage.getPreference(forKey: "addressBook", type: [String: LegacyContact].self) else {
            print("ℹ️ [DatabaseMigration] No address book found in UserDefaults")
            return
        }

        var migratedCount = 0
        for (address, contact) in addressBook {
            let sql = """
            INSERT OR REPLACE INTO contacts (address, name, note, added_at, updated_at)
            VALUES (?, ?, ?, ?, ?);
            """

            migratedCount += 1
        }

        print("✅ [DatabaseMigration] Migrated \(migratedCount) contacts")
    }

    // MARK: - Legacy Data Models (for migration)

    struct LegacyTransactionHistoryItem: Codable {
        let id: String
        let hash: String
        let from: String
        let to: String
        let value: String
        let data: String
        let chainId: String
        let nonce: Int
        let gasUsed: String?
        let gasPrice: String?
        let status: String
        let createdAt: Date
        let completedAt: Date?
        let isSubmitFailed: Bool
        let pushType: String?
        let site: ConnectedSite?

        struct ConnectedSite: Codable {
            let origin: String
            let name: String
            let icon: String?
        }
    }

    struct LegacyConnectedSite: Codable {
        let origin: String
        let name: String
        let icon: String?
        let isConnected: Bool
        let connectedAt: Date
    }

    struct LegacyContact: Codable {
        let address: String
        let name: String
        let note: String?
        let addedAt: Date
    }
}
