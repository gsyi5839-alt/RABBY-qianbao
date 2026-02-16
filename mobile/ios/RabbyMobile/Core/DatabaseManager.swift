import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQLite Database Manager for structured data storage
/// Handles transaction history, tokens, NFTs, and other relational data
/// Uses iOS built-in SQLite3 (no external dependencies)
@MainActor
class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dbPath: String
    private let dbQueue = DispatchQueue(label: "com.rabby.database", qos: .userInitiated)

    // MARK: - Initialization

    private init() {
        // Store database in Application Support directory
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let rabbyDir = appSupportURL.appendingPathComponent("RabbyWallet")

        // Create directory if needed
        try? fileManager.createDirectory(at: rabbyDir, withIntermediateDirectories: true)

        dbPath = rabbyDir.appendingPathComponent("rabby.sqlite").path
        print("📁 [DatabaseManager] Database path: \(dbPath)")

        openDatabase()
        createTables()
    }

    // MARK: - Database Lifecycle

    private func openDatabase() {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            print("❌ [DatabaseManager] Failed to open database")
            return
        }

        // Enable Write-Ahead Logging for better concurrency
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)

        // Enable foreign keys
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)

        print("✅ [DatabaseManager] Database opened successfully")
    }

    private func createTables() {
        // Transaction History Table
        let createTransactionsTable = """
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            hash TEXT NOT NULL,
            address TEXT NOT NULL,
            chain_id TEXT NOT NULL,
            from_address TEXT NOT NULL,
            to_address TEXT,
            value TEXT,
            data TEXT,
            nonce INTEGER NOT NULL,
            gas_used TEXT,
            gas_price TEXT,
            max_fee_per_gas TEXT,
            max_priority_fee_per_gas TEXT,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            completed_at INTEGER,
            is_submit_failed INTEGER DEFAULT 0,
            push_type TEXT,
            site_origin TEXT,
            site_name TEXT,
            site_icon TEXT,
            tx_type TEXT,
            UNIQUE(hash, chain_id)
        );
        """

        // Create indexes for faster queries
        let createTransactionIndexes = """
        CREATE INDEX IF NOT EXISTS idx_tx_address ON transactions(address);
        CREATE INDEX IF NOT EXISTS idx_tx_chain ON transactions(chain_id);
        CREATE INDEX IF NOT EXISTS idx_tx_status ON transactions(status);
        CREATE INDEX IF NOT EXISTS idx_tx_created ON transactions(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_tx_hash ON transactions(hash);
        """

        // Token Cache Table
        let createTokensTable = """
        CREATE TABLE IF NOT EXISTS tokens (
            id TEXT PRIMARY KEY,
            address TEXT NOT NULL,
            chain_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            name TEXT NOT NULL,
            decimals INTEGER NOT NULL,
            logo_url TEXT,
            price_usd REAL,
            balance TEXT,
            raw_amount TEXT,
            is_custom INTEGER DEFAULT 0,
            is_verified INTEGER DEFAULT 1,
            is_hidden INTEGER DEFAULT 0,
            updated_at INTEGER NOT NULL,
            UNIQUE(address, chain_id)
        );
        """

        let createTokenIndexes = """
        CREATE INDEX IF NOT EXISTS idx_token_chain ON tokens(chain_id);
        CREATE INDEX IF NOT EXISTS idx_token_symbol ON tokens(symbol);
        CREATE INDEX IF NOT EXISTS idx_token_hidden ON tokens(is_hidden);
        """

        // NFT Collection Table
        let createNFTsTable = """
        CREATE TABLE IF NOT EXISTS nfts (
            id TEXT PRIMARY KEY,
            contract_address TEXT NOT NULL,
            token_id TEXT NOT NULL,
            chain_id TEXT NOT NULL,
            owner_address TEXT NOT NULL,
            name TEXT,
            description TEXT,
            image_url TEXT,
            collection_name TEXT,
            amount TEXT DEFAULT '1',
            is_erc1155 INTEGER DEFAULT 0,
            is_starred INTEGER DEFAULT 0,
            updated_at INTEGER NOT NULL,
            UNIQUE(contract_address, token_id, chain_id)
        );
        """

        let createNFTIndexes = """
        CREATE INDEX IF NOT EXISTS idx_nft_owner ON nfts(owner_address);
        CREATE INDEX IF NOT EXISTS idx_nft_chain ON nfts(chain_id);
        CREATE INDEX IF NOT EXISTS idx_nft_starred ON nfts(is_starred);
        CREATE INDEX IF NOT EXISTS idx_nft_collection ON nfts(collection_name);
        """

        // Swap History Table
        let createSwapHistoryTable = """
        CREATE TABLE IF NOT EXISTS swap_history (
            id TEXT PRIMARY KEY,
            address TEXT NOT NULL,
            chain_id TEXT NOT NULL,
            tx_hash TEXT,
            from_token_id TEXT NOT NULL,
            from_token_symbol TEXT NOT NULL,
            from_amount TEXT NOT NULL,
            to_token_id TEXT NOT NULL,
            to_token_symbol TEXT NOT NULL,
            to_amount TEXT NOT NULL,
            dex_id TEXT NOT NULL,
            dex_name TEXT,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            completed_at INTEGER
        );
        """

        let createSwapIndexes = """
        CREATE INDEX IF NOT EXISTS idx_swap_address ON swap_history(address);
        CREATE INDEX IF NOT EXISTS idx_swap_created ON swap_history(created_at DESC);
        """

        // Bridge History Table
        let createBridgeHistoryTable = """
        CREATE TABLE IF NOT EXISTS bridge_history (
            id TEXT PRIMARY KEY,
            address TEXT NOT NULL,
            from_chain_id TEXT NOT NULL,
            to_chain_id TEXT NOT NULL,
            tx_hash TEXT,
            token_symbol TEXT NOT NULL,
            amount TEXT NOT NULL,
            aggregator_id TEXT NOT NULL,
            aggregator_name TEXT,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            completed_at INTEGER
        );
        """

        let createBridgeIndexes = """
        CREATE INDEX IF NOT EXISTS idx_bridge_address ON bridge_history(address);
        CREATE INDEX IF NOT EXISTS idx_bridge_created ON bridge_history(created_at DESC);
        """

        // Connected Sites Table
        let createConnectedSitesTable = """
        CREATE TABLE IF NOT EXISTS connected_sites (
            origin TEXT PRIMARY KEY,
            url TEXT,
            name TEXT NOT NULL,
            icon TEXT,
            chain_id TEXT,
            permissions_json TEXT,
            connection_type TEXT,
            connected_address TEXT,
            is_connected INTEGER DEFAULT 1,
            connected_at INTEGER NOT NULL,
            last_used_at INTEGER
        );
        """

        // Address Book / Contacts Table
        let createContactsTable = """
        CREATE TABLE IF NOT EXISTS contacts (
            id TEXT,
            address TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            is_alias INTEGER DEFAULT 0,
            is_contact INTEGER DEFAULT 1,
            cex_id TEXT,
            note TEXT,
            added_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        """

        // Extension-style key-value store for JSON/blob payloads.
        let createKVStoreTable = """
        CREATE TABLE IF NOT EXISTS kv_store (
            key TEXT PRIMARY KEY,
            value BLOB NOT NULL,
            updated_at INTEGER NOT NULL
        );
        """

        // Execute all table creation statements
        let statements = [
            createTransactionsTable,
            createTransactionIndexes,
            createTokensTable,
            createTokenIndexes,
            createNFTsTable,
            createNFTIndexes,
            createSwapHistoryTable,
            createSwapIndexes,
            createBridgeHistoryTable,
            createBridgeIndexes,
            createConnectedSitesTable,
            createContactsTable,
            createKVStoreTable
        ]

        for statement in statements {
            if sqlite3_exec(db, statement, nil, nil, nil) != SQLITE_OK {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("❌ [DatabaseManager] Failed to execute statement: \(errorMessage)")
            }
        }

        applySchemaMigrations()

        print("✅ [DatabaseManager] All tables created successfully")
    }

    private func applySchemaMigrations() {
        ensureColumn(table: "connected_sites", column: "url", definition: "TEXT")
        ensureColumn(table: "connected_sites", column: "chain_id", definition: "TEXT")
        ensureColumn(table: "connected_sites", column: "permissions_json", definition: "TEXT")
        ensureColumn(table: "connected_sites", column: "connection_type", definition: "TEXT")
        ensureColumn(table: "connected_sites", column: "connected_address", definition: "TEXT")

        ensureColumn(table: "contacts", column: "id", definition: "TEXT")
        ensureColumn(table: "contacts", column: "is_alias", definition: "INTEGER DEFAULT 0")
        ensureColumn(table: "contacts", column: "is_contact", definition: "INTEGER DEFAULT 1")
        ensureColumn(table: "contacts", column: "cex_id", definition: "TEXT")
    }

    private func ensureColumn(table: String, column: String, definition: String) {
        guard !columnExists(table: table, column: column) else { return }
        let sql = "ALTER TABLE \(table) ADD COLUMN \(column) \(definition);"
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ [DatabaseManager] Failed to migrate \(table).\(column): \(errorMessage)")
        }
    }

    private func columnExists(table: String, column: String) -> Bool {
        let sql = "PRAGMA table_info(\(table));"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let cString = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: cString) == column {
                return true
            }
        }

        return false
    }

    // MARK: - Transaction Operations

    struct Transaction {
        let id: String
        let hash: String
        let address: String
        let chainId: String
        let fromAddress: String
        let toAddress: String?
        let value: String?
        let data: String?
        let nonce: Int
        let gasUsed: String?
        let gasPrice: String?
        let maxFeePerGas: String?
        let maxPriorityFeePerGas: String?
        let status: String
        let createdAt: Date
        let completedAt: Date?
        let isSubmitFailed: Bool
        let pushType: String?
        let siteOrigin: String?
        let siteName: String?
        let siteIcon: String?
        let txType: String?
    }

    func insertTransaction(_ tx: Transaction) throws {
        let sql = """
        INSERT OR REPLACE INTO transactions
        (id, hash, address, chain_id, from_address, to_address, value, data, nonce,
         gas_used, gas_price, max_fee_per_gas, max_priority_fee_per_gas, status,
         created_at, completed_at, is_submit_failed, push_type, site_origin, site_name, site_icon, tx_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, (tx.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (tx.hash as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (tx.address as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (tx.chainId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 5, (tx.fromAddress as NSString).utf8String, -1, nil)
        bindTextOrNull(statement, 6, tx.toAddress)
        bindTextOrNull(statement, 7, tx.value)
        bindTextOrNull(statement, 8, tx.data)
        sqlite3_bind_int(statement, 9, Int32(tx.nonce))
        bindTextOrNull(statement, 10, tx.gasUsed)
        bindTextOrNull(statement, 11, tx.gasPrice)
        bindTextOrNull(statement, 12, tx.maxFeePerGas)
        bindTextOrNull(statement, 13, tx.maxPriorityFeePerGas)
        sqlite3_bind_text(statement, 14, (tx.status as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(statement, 15, Int64(tx.createdAt.timeIntervalSince1970))
        bindInt64OrNull(statement, 16, tx.completedAt?.timeIntervalSince1970)
        sqlite3_bind_int(statement, 17, tx.isSubmitFailed ? 1 : 0)
        bindTextOrNull(statement, 18, tx.pushType)
        bindTextOrNull(statement, 19, tx.siteOrigin)
        bindTextOrNull(statement, 20, tx.siteName)
        bindTextOrNull(statement, 21, tx.siteIcon)
        bindTextOrNull(statement, 22, tx.txType)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func getTransactions(address: String, chainId: String? = nil, limit: Int = 100) throws -> [Transaction] {
        var sql = "SELECT * FROM transactions WHERE address = ?"
        if chainId != nil {
            sql += " AND chain_id = ?"
        }
        sql += " ORDER BY created_at DESC LIMIT ?;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, (address as NSString).utf8String, -1, nil)
        var bindIndex: Int32 = 2
        if let chainId = chainId {
            sqlite3_bind_text(statement, bindIndex, (chainId as NSString).utf8String, -1, nil)
            bindIndex += 1
        }
        sqlite3_bind_int(statement, bindIndex, Int32(limit))

        var transactions: [Transaction] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let tx = Transaction(
                id: String(cString: sqlite3_column_text(statement, 0)),
                hash: String(cString: sqlite3_column_text(statement, 1)),
                address: String(cString: sqlite3_column_text(statement, 2)),
                chainId: String(cString: sqlite3_column_text(statement, 3)),
                fromAddress: String(cString: sqlite3_column_text(statement, 4)),
                toAddress: getTextOrNull(statement, 5),
                value: getTextOrNull(statement, 6),
                data: getTextOrNull(statement, 7),
                nonce: Int(sqlite3_column_int(statement, 8)),
                gasUsed: getTextOrNull(statement, 9),
                gasPrice: getTextOrNull(statement, 10),
                maxFeePerGas: getTextOrNull(statement, 11),
                maxPriorityFeePerGas: getTextOrNull(statement, 12),
                status: String(cString: sqlite3_column_text(statement, 13)),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 14)),
                completedAt: getDateOrNull(statement, 15),
                isSubmitFailed: sqlite3_column_int(statement, 16) == 1,
                pushType: getTextOrNull(statement, 17),
                siteOrigin: getTextOrNull(statement, 18),
                siteName: getTextOrNull(statement, 19),
                siteIcon: getTextOrNull(statement, 20),
                txType: getTextOrNull(statement, 21)
            )
            transactions.append(tx)
        }

        return transactions
    }

    func getPendingTransactions(address: String) throws -> [Transaction] {
        let sql = "SELECT * FROM transactions WHERE address = ? AND status = 'pending' ORDER BY created_at DESC;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, (address as NSString).utf8String, -1, nil)

        var transactions: [Transaction] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let tx = Transaction(
                id: String(cString: sqlite3_column_text(statement, 0)),
                hash: String(cString: sqlite3_column_text(statement, 1)),
                address: String(cString: sqlite3_column_text(statement, 2)),
                chainId: String(cString: sqlite3_column_text(statement, 3)),
                fromAddress: String(cString: sqlite3_column_text(statement, 4)),
                toAddress: getTextOrNull(statement, 5),
                value: getTextOrNull(statement, 6),
                data: getTextOrNull(statement, 7),
                nonce: Int(sqlite3_column_int(statement, 8)),
                gasUsed: getTextOrNull(statement, 9),
                gasPrice: getTextOrNull(statement, 10),
                maxFeePerGas: getTextOrNull(statement, 11),
                maxPriorityFeePerGas: getTextOrNull(statement, 12),
                status: String(cString: sqlite3_column_text(statement, 13)),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 14)),
                completedAt: getDateOrNull(statement, 15),
                isSubmitFailed: sqlite3_column_int(statement, 16) == 1,
                pushType: getTextOrNull(statement, 17),
                siteOrigin: getTextOrNull(statement, 18),
                siteName: getTextOrNull(statement, 19),
                siteIcon: getTextOrNull(statement, 20),
                txType: getTextOrNull(statement, 21)
            )
            transactions.append(tx)
        }

        return transactions
    }

    func updateTransactionStatus(hash: String, status: String, completedAt: Date? = nil) throws {
        let sql = "UPDATE transactions SET status = ?, completed_at = ? WHERE hash = ?;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, (status as NSString).utf8String, -1, nil)
        bindInt64OrNull(statement, 2, completedAt?.timeIntervalSince1970)
        sqlite3_bind_text(statement, 3, (hash as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func deleteTransaction(id: String) throws {
        try executeUpdate("DELETE FROM transactions WHERE id = ?;", params: [id])
    }

    // MARK: - Token Operations

    struct Token {
        let id: String
        let address: String
        let chainId: String
        let symbol: String
        let name: String
        let decimals: Int
        let logoUrl: String?
        let priceUsd: Double?
        let balance: String?
        let rawAmount: String?
        let isCustom: Bool
        let isVerified: Bool
        let isHidden: Bool
        let updatedAt: Date
    }

    func insertToken(_ token: Token) throws {
        let sql = """
        INSERT OR REPLACE INTO tokens
        (id, address, chain_id, symbol, name, decimals, logo_url, price_usd, balance, raw_amount,
         is_custom, is_verified, is_hidden, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, (token.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (token.address as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (token.chainId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (token.symbol as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 5, (token.name as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 6, Int32(token.decimals))
        bindTextOrNull(statement, 7, token.logoUrl)
        bindDoubleOrNull(statement, 8, token.priceUsd)
        bindTextOrNull(statement, 9, token.balance)
        bindTextOrNull(statement, 10, token.rawAmount)
        sqlite3_bind_int(statement, 11, token.isCustom ? 1 : 0)
        sqlite3_bind_int(statement, 12, token.isVerified ? 1 : 0)
        sqlite3_bind_int(statement, 13, token.isHidden ? 1 : 0)
        sqlite3_bind_int64(statement, 14, Int64(token.updatedAt.timeIntervalSince1970))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func getTokens(chainId: String? = nil, includeHidden: Bool = false) throws -> [Token] {
        var sql = "SELECT * FROM tokens WHERE 1=1"
        if let chain = chainId {
            sql += " AND chain_id = '\(chain)'"
        }
        if !includeHidden {
            sql += " AND is_hidden = 0"
        }
        sql += " ORDER BY symbol ASC;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        var tokens: [Token] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let token = Token(
                id: String(cString: sqlite3_column_text(statement, 0)),
                address: String(cString: sqlite3_column_text(statement, 1)),
                chainId: String(cString: sqlite3_column_text(statement, 2)),
                symbol: String(cString: sqlite3_column_text(statement, 3)),
                name: String(cString: sqlite3_column_text(statement, 4)),
                decimals: Int(sqlite3_column_int(statement, 5)),
                logoUrl: getTextOrNull(statement, 6),
                priceUsd: getDoubleOrNull(statement, 7),
                balance: getTextOrNull(statement, 8),
                rawAmount: getTextOrNull(statement, 9),
                isCustom: sqlite3_column_int(statement, 10) == 1,
                isVerified: sqlite3_column_int(statement, 11) == 1,
                isHidden: sqlite3_column_int(statement, 12) == 1,
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 13))
            )
            tokens.append(token)
        }

        return tokens
    }

    // MARK: - Connected Site Operations

    struct ConnectedSiteRecord {
        let origin: String
        let url: String
        let name: String
        let icon: String?
        let chainId: String?
        let permissionsJSON: String?
        let connectionType: String?
        let connectedAddress: String?
        let isConnected: Bool
        let connectedAt: Date
        let lastUsedAt: Date?
    }

    func upsertConnectedSite(_ site: ConnectedSiteRecord) throws {
        let sql = """
        INSERT OR REPLACE INTO connected_sites
        (origin, url, name, icon, chain_id, permissions_json, connection_type, connected_address, is_connected, connected_at, last_used_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, (site.origin as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (site.url as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (site.name as NSString).utf8String, -1, nil)
        bindTextOrNull(statement, 4, site.icon)
        bindTextOrNull(statement, 5, site.chainId)
        bindTextOrNull(statement, 6, site.permissionsJSON)
        bindTextOrNull(statement, 7, site.connectionType)
        bindTextOrNull(statement, 8, site.connectedAddress)
        sqlite3_bind_int(statement, 9, site.isConnected ? 1 : 0)
        sqlite3_bind_int64(statement, 10, Int64(site.connectedAt.timeIntervalSince1970))
        bindInt64OrNull(statement, 11, site.lastUsedAt?.timeIntervalSince1970)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func replaceConnectedSites(_ sites: [ConnectedSiteRecord]) throws {
        guard sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }

        do {
            try executeUpdate("DELETE FROM connected_sites;", params: [])
            for site in sites {
                try upsertConnectedSite(site)
            }
            guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
        } catch {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    func getConnectedSites(includeDisconnected: Bool = true) throws -> [ConnectedSiteRecord] {
        var sql = "SELECT origin, url, name, icon, chain_id, permissions_json, connection_type, connected_address, is_connected, connected_at, last_used_at FROM connected_sites"
        if !includeDisconnected {
            sql += " WHERE is_connected = 1"
        }
        sql += " ORDER BY connected_at DESC;"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        var sites: [ConnectedSiteRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let origin = String(cString: sqlite3_column_text(statement, 0))
            let url = getTextOrNull(statement, 1) ?? origin
            let name = String(cString: sqlite3_column_text(statement, 2))
            let icon = getTextOrNull(statement, 3)
            let chainId = getTextOrNull(statement, 4)
            let permissionsJSON = getTextOrNull(statement, 5)
            let connectionType = getTextOrNull(statement, 6)
            let connectedAddress = getTextOrNull(statement, 7)
            let isConnected = sqlite3_column_int(statement, 8) == 1
            let connectedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 9))
            let lastUsedAt = getDateOrNull(statement, 10)

            sites.append(
                ConnectedSiteRecord(
                    origin: origin,
                    url: url,
                    name: name,
                    icon: icon,
                    chainId: chainId,
                    permissionsJSON: permissionsJSON,
                    connectionType: connectionType,
                    connectedAddress: connectedAddress,
                    isConnected: isConnected,
                    connectedAt: connectedAt,
                    lastUsedAt: lastUsedAt
                )
            )
        }

        return sites
    }

    func deleteConnectedSite(origin: String) throws {
        try executeUpdate("DELETE FROM connected_sites WHERE origin = ?;", params: [origin])
    }

    // MARK: - Contact Operations

    struct ContactRecord {
        let id: String
        let address: String
        let name: String
        let isAlias: Bool
        let isContact: Bool
        let cexId: String?
        let note: String?
        let addedAt: Date
        let updatedAt: Date
    }

    func upsertContact(_ contact: ContactRecord) throws {
        let sql = """
        INSERT OR REPLACE INTO contacts
        (id, address, name, is_alias, is_contact, cex_id, note, added_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, (contact.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (contact.address.lowercased() as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (contact.name as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 4, contact.isAlias ? 1 : 0)
        sqlite3_bind_int(statement, 5, contact.isContact ? 1 : 0)
        bindTextOrNull(statement, 6, contact.cexId)
        bindTextOrNull(statement, 7, contact.note)
        sqlite3_bind_int64(statement, 8, Int64(contact.addedAt.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 9, Int64(contact.updatedAt.timeIntervalSince1970))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func replaceContacts(_ contacts: [ContactRecord]) throws {
        guard sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }

        do {
            try executeUpdate("DELETE FROM contacts;", params: [])
            for contact in contacts {
                try upsertContact(contact)
            }
            guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
        } catch {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    func getContacts() throws -> [ContactRecord] {
        let sql = """
        SELECT id, address, name, is_alias, is_contact, cex_id, note, added_at, updated_at
        FROM contacts
        ORDER BY updated_at DESC;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        var contacts: [ContactRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            contacts.append(
                ContactRecord(
                    id: getTextOrNull(statement, 0) ?? UUID().uuidString,
                    address: String(cString: sqlite3_column_text(statement, 1)),
                    name: String(cString: sqlite3_column_text(statement, 2)),
                    isAlias: sqlite3_column_int(statement, 3) == 1,
                    isContact: sqlite3_column_int(statement, 4) == 1,
                    cexId: getTextOrNull(statement, 5),
                    note: getTextOrNull(statement, 6),
                    addedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7)),
                    updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
                )
            )
        }

        return contacts
    }

    func deleteContact(address: String) throws {
        try executeUpdate("DELETE FROM contacts WHERE address = ?;", params: [address.lowercased()])
    }

    // MARK: - KV Store Operations

    func setValueData(_ data: Data, forKey key: String) throws {
        let sql = """
        INSERT OR REPLACE INTO kv_store (key, value, updated_at)
        VALUES (?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)
        _ = data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, 2, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
        }
        sqlite3_bind_int64(statement, 3, Int64(Date().timeIntervalSince1970))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func getValueData(forKey key: String) throws -> Data? {
        let sql = "SELECT value FROM kv_store WHERE key = ? LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        guard let bytes = sqlite3_column_blob(statement, 0) else {
            return nil
        }
        let length = Int(sqlite3_column_bytes(statement, 0))
        return Data(bytes: bytes, count: length)
    }

    func removeValue(forKey key: String) throws {
        try executeUpdate("DELETE FROM kv_store WHERE key = ?;", params: [key])
    }

    // MARK: - Utility Methods

    private func executeUpdate(_ sql: String, params: [String?]) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }

        for (index, param) in params.enumerated() {
            if let param {
                sqlite3_bind_text(statement, Int32(index + 1), (param as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, Int32(index + 1))
            }
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func bindTextOrNull(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value = value {
            sqlite3_bind_text(statement, index, (value as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bindInt64OrNull(_ statement: OpaquePointer?, _ index: Int32, _ value: TimeInterval?) {
        if let value = value {
            sqlite3_bind_int64(statement, index, Int64(value))
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bindDoubleOrNull(_ statement: OpaquePointer?, _ index: Int32, _ value: Double?) {
        if let value = value {
            sqlite3_bind_double(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func getTextOrNull(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }

    private func getDateOrNull(_ statement: OpaquePointer?, _ index: Int32) -> Date? {
        let timestamp = sqlite3_column_double(statement, index)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    private func getDoubleOrNull(_ statement: OpaquePointer?, _ index: Int32) -> Double? {
        let value = sqlite3_column_double(statement, index)
        return sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : value
    }

    // MARK: - Database Maintenance

    func vacuum() throws {
        guard sqlite3_exec(db, "VACUUM;", nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func clearAllData() throws {
        let tables = ["transactions", "tokens", "nfts", "swap_history", "bridge_history", "connected_sites", "contacts"]
        for table in tables {
            guard sqlite3_exec(db, "DELETE FROM \(table);", nil, nil, nil) == SQLITE_OK else {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
        try vacuum()
    }

    func closeDatabase() {
        guard let db = db else { return }
        sqlite3_close(db)
        self.db = nil
        print("📁 [DatabaseManager] Database closed")
    }

    deinit {
        // Close database synchronously (deinit cannot be async)
        if let db = db {
            sqlite3_close(db)
            print("📁 [DatabaseManager] Database closed in deinit")
        }
    }
}

// MARK: - Errors

enum DatabaseError: Error, LocalizedError {
    case prepareFailed(String)
    case executeFailed(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .prepareFailed(let message):
            return "Failed to prepare SQL statement: \(message)"
        case .executeFailed(let message):
            return "Failed to execute SQL: \(message)"
        case .notFound:
            return "Record not found"
        }
    }
}
