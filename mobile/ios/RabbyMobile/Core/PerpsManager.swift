import Foundation
import Combine
import Security

// MARK: - Data Models

enum PositionSide: String, Codable, CaseIterable {
    case long = "long"
    case short = "short"

    var displayName: String {
        switch self {
        case .long: return "Long"
        case .short: return "Short"
        }
    }
}

enum PerpsOrderType: String, Codable, CaseIterable {
    case limit = "limit"
    case market = "market"
    case stopLimit = "stop-limit"
    case stopMarket = "stop-market"
    case twap = "TWAP"

    var displayName: String {
        switch self {
        case .limit: return "Limit"
        case .market: return "Market"
        case .stopLimit: return "Stop Limit"
        case .stopMarket: return "Stop Market"
        case .twap: return "TWAP"
        }
    }
}

enum PerpsOrderStatus: String, Codable {
    case pending = "pending"
    case open = "open"
    case partiallyFilled = "partially_filled"
    case filled = "filled"
    case cancelled = "cancelled"
    case rejected = "rejected"
    case expired = "expired"
}

struct PerpsMarket: Codable, Identifiable {
    let id: String
    let symbol: String
    let markPrice: Double
    let indexPrice: Double
    let change24h: Double
    let volume24h: Double
    let fundingRate: Double
    let openInterest: Double
    let maxLeverage: Int

    /// Human-readable formatted mark price
    var formattedMarkPrice: String {
        if markPrice >= 1000 {
            return String(format: "$%.2f", markPrice)
        } else if markPrice >= 1 {
            return String(format: "$%.4f", markPrice)
        } else {
            return String(format: "$%.6f", markPrice)
        }
    }

    /// Formatted 24h change percentage
    var formattedChange24h: String {
        return String(format: "%+.2f%%", change24h * 100)
    }

    /// Formatted funding rate
    var formattedFundingRate: String {
        return String(format: "%.4f%%", fundingRate * 100)
    }

    /// Formatted 24h volume
    var formattedVolume24h: String {
        if volume24h >= 1_000_000_000 {
            return String(format: "$%.1fB", volume24h / 1_000_000_000)
        } else if volume24h >= 1_000_000 {
            return String(format: "$%.1fM", volume24h / 1_000_000)
        } else if volume24h >= 1_000 {
            return String(format: "$%.1fK", volume24h / 1_000)
        }
        return String(format: "$%.0f", volume24h)
    }

    var isPositiveChange: Bool { change24h >= 0 }
}

struct PerpsPosition: Codable, Identifiable {
    let id: String
    let symbol: String
    let side: PositionSide
    let size: Double
    let entryPrice: Double
    let markPrice: Double
    let unrealizedPnl: Double
    let unrealizedPnlPercent: Double
    let leverage: Double
    let liquidationPrice: Double
    let margin: Double
    let marginRatio: Double

    /// Formatted PnL string with sign
    var formattedPnl: String {
        let sign = unrealizedPnl >= 0 ? "+" : ""
        return "\(sign)$\(String(format: "%.2f", unrealizedPnl))"
    }

    /// Formatted PnL percentage
    var formattedPnlPercent: String {
        return String(format: "%+.2f%%", unrealizedPnlPercent)
    }

    /// Notional value of the position
    var notionalValue: Double {
        return size * markPrice
    }

    var isProfitable: Bool { unrealizedPnl >= 0 }

    /// Margin ratio health status
    var marginHealthStatus: MarginHealth {
        if marginRatio < 0.1 { return .danger }
        if marginRatio < 0.25 { return .warning }
        return .safe
    }

    enum MarginHealth: String {
        case safe, warning, danger
    }
}

struct PerpsOrder: Codable, Identifiable {
    let id: String
    let symbol: String
    let side: PositionSide
    let orderType: PerpsOrderType
    let size: Double
    let price: Double?
    let triggerPrice: Double?
    let filledSize: Double
    let status: PerpsOrderStatus
    let leverage: Double
    let reduceOnly: Bool
    let createdAt: Date
    let updatedAt: Date?

    /// Remaining unfilled size
    var remainingSize: Double {
        return size - filledSize
    }

    /// Percentage of order filled
    var fillPercent: Double {
        guard size > 0 else { return 0 }
        return (filledSize / size) * 100
    }

    /// Whether the order can be cancelled
    var isCancellable: Bool {
        return status == .open || status == .pending || status == .partiallyFilled
    }
}

// MARK: - API Response Wrappers

/// Generic API response from the perps endpoints
private struct PerpsAPIResponse<T: Codable>: Codable {
    let data: T?
    let error: String?
    let code: Int?
}

/// Raw market data from API (snake_case mapping)
private struct RawPerpsMarket: Codable {
    let id: String?
    let symbol: String
    let mark_price: Double?
    let index_price: Double?
    let change_24h: Double?
    let volume_24h: Double?
    let funding_rate: Double?
    let open_interest: Double?
    let max_leverage: Int?

    func toPerpsMarket() -> PerpsMarket {
        return PerpsMarket(
            id: id ?? symbol,
            symbol: symbol,
            markPrice: mark_price ?? 0,
            indexPrice: index_price ?? 0,
            change24h: change_24h ?? 0,
            volume24h: volume_24h ?? 0,
            fundingRate: funding_rate ?? 0,
            openInterest: open_interest ?? 0,
            maxLeverage: max_leverage ?? 50
        )
    }
}

/// Raw position data from API
private struct RawPerpsPosition: Codable {
    let id: String?
    let symbol: String
    let side: String
    let size: Double
    let entry_price: Double
    let mark_price: Double?
    let unrealized_pnl: Double?
    let unrealized_pnl_percent: Double?
    let leverage: Double
    let liquidation_price: Double?
    let margin: Double?
    let margin_ratio: Double?

    func toPerpsPosition() -> PerpsPosition {
        let resolvedSide = PositionSide(rawValue: side.lowercased()) ?? .long
        let entryPx = entry_price
        let markPx = mark_price ?? entryPx
        let pnl = unrealized_pnl ?? computePnl(side: resolvedSide, entryPrice: entryPx, markPrice: markPx, size: size)
        let pnlPercent = unrealized_pnl_percent ?? {
            guard entryPx > 0 else { return 0 }
            return (pnl / (size * entryPx)) * 100
        }()
        let marginVal = margin ?? (size * entryPx / leverage)
        let marginRatioVal = margin_ratio ?? {
            guard marginVal > 0 else { return 0 }
            return marginVal / (size * markPx)
        }()

        return PerpsPosition(
            id: id ?? "\(symbol)-\(side)",
            symbol: symbol,
            side: resolvedSide,
            size: size,
            entryPrice: entryPx,
            markPrice: markPx,
            unrealizedPnl: pnl,
            unrealizedPnlPercent: pnlPercent,
            leverage: leverage,
            liquidationPrice: liquidation_price ?? 0,
            margin: marginVal,
            marginRatio: marginRatioVal
        )
    }

    private func computePnl(side: PositionSide, entryPrice: Double, markPrice: Double, size: Double) -> Double {
        switch side {
        case .long: return (markPrice - entryPrice) * size
        case .short: return (entryPrice - markPrice) * size
        }
    }
}

/// Raw order data from API
private struct RawPerpsOrder: Codable {
    let id: String
    let symbol: String
    let side: String
    let order_type: String
    let size: Double
    let price: Double?
    let trigger_price: Double?
    let filled_size: Double?
    let status: String
    let leverage: Double?
    let reduce_only: Bool?
    let created_at: Double?
    let updated_at: Double?

    func toPerpsOrder() -> PerpsOrder {
        return PerpsOrder(
            id: id,
            symbol: symbol,
            side: PositionSide(rawValue: side.lowercased()) ?? .long,
            orderType: PerpsOrderType(rawValue: order_type) ?? .limit,
            size: size,
            price: price,
            triggerPrice: trigger_price,
            filledSize: filled_size ?? 0,
            status: PerpsOrderStatus(rawValue: status) ?? .pending,
            leverage: leverage ?? 1,
            reduceOnly: reduce_only ?? false,
            createdAt: Date(timeIntervalSince1970: created_at ?? Date().timeIntervalSince1970),
            updatedAt: updated_at.map { Date(timeIntervalSince1970: $0) }
        )
    }
}

// MARK: - PerpsManager

/// Perpetuals Trading Manager - HyperLiquid-style perps trading
/// Corresponds to: src/background/service/perps.ts
@MainActor
class PerpsManager: ObservableObject {
    static let shared = PerpsManager()

    // MARK: - Published State

    @Published var currentAccount: PerpsAccount?
    @Published var lastUsedAccount: PerpsAccount?
    @Published var hasDoneNewUserProcess: Bool = false
    @Published var favoritedCoins: [String] = ["BTC", "ETH", "SOL"]
    @Published var marketSlippage: Double = 0.08
    @Published var soundEnabled: Bool = true
    @Published var quoteUnit: QuoteUnit = .base

    /// All available perps markets
    @Published var markets: [PerpsMarket] = []
    /// Current open positions for the active account
    @Published var positions: [PerpsPosition] = []
    /// Current active orders for the active account
    @Published var orders: [PerpsOrder] = []

    @Published var isLoading = false
    @Published var isLoadingMarkets = false
    @Published var isLoadingPositions = false
    @Published var isLoadingOrders = false
    @Published var lastError: PerpsError?

    /// Timestamp of the last successful data refresh
    @Published var lastMarketsRefresh: Date?
    @Published var lastPositionsRefresh: Date?
    @Published var lastOrdersRefresh: Date?

    // MARK: - Private State

    private let storage = StorageManager.shared
    private let api = OpenAPIService.shared
    private let storageKey = "perps_store"
    private let perpsKeychainService = "com.rabby.wallet.perps"
    private let agentVaultsAccountKey = "agentVaults"
    private var agentWallets: [String: AgentWalletInfo] = [:]

    /// Timer for auto-refreshing market data (5 seconds)
    private var marketsRefreshTimer: Timer?
    /// Timer for auto-refreshing positions and orders (10 seconds)
    private var accountDataRefreshTimer: Timer?

    /// Maximum retry attempts for failed API calls
    private let maxRetryAttempts = 3
    /// Base delay between retries (doubles each attempt)
    private let retryBaseDelay: TimeInterval = 1.0

    // MARK: - Sub-types

    struct PerpsAccount: Codable, Identifiable {
        let address: String
        let type: String
        let brandName: String
        var id: String { address }
    }

    struct AgentWalletInfo: Codable {
        let vault: String
        var agentAddress: String
        var approveSignatures: [ApproveSignature]
    }

    struct AgentWalletPreference: Codable {
        var agentAddress: String
        var approveSignatures: [ApproveSignature]
    }

    struct ApproveSignature: Codable {
        let type: String // "approveAgent" | "approveBuilderFee"
        let signature: String
        let nonce: Int
    }

    enum QuoteUnit: String, Codable, CaseIterable {
        case base = "base"
        case usd = "usd"
    }

    // Keep legacy aliases for backward compatibility with the UI layer
    typealias Position = PerpsPosition
    typealias Order = PerpsOrder

    // MARK: - Init

    private init() {
        loadFromStorage()
    }

    deinit {
        marketsRefreshTimer?.invalidate()
        accountDataRefreshTimer?.invalidate()
    }

    // MARK: - Account Management

    func setCurrentAccount(_ account: PerpsAccount?) {
        if let account = account {
            lastUsedAccount = account
        }
        currentAccount = account
        saveToStorage()

        if account != nil {
            startAutoRefresh()
            Task { await refreshAllData() }
        } else {
            stopAutoRefresh()
            positions = []
            orders = []
        }
    }

    func syncCurrentAccount(from walletAccount: Account?) {
        guard let walletAccount else {
            setCurrentAccount(nil)
            return
        }

        let mapped = PerpsAccount(
            address: walletAccount.address,
            type: walletAccount.type.rawValue,
            brandName: walletAccount.brandName
        )

        if currentAccount?.address.lowercased() != mapped.address.lowercased() {
            setCurrentAccount(mapped)
        } else if currentAccount?.type != mapped.type || currentAccount?.brandName != mapped.brandName {
            currentAccount = mapped
            saveToStorage()
        }
    }

    func getLastUsedAccount() -> PerpsAccount? {
        return lastUsedAccount
    }

    @discardableResult
    func ensureAgentWallet(address: String) async throws -> AgentWalletInfo {
        let normalized = address.lowercased()
        if let existing = agentWallets[normalized] {
            return existing
        }

        _ = try await createAgentWallet(masterAddress: normalized)
        guard let wallet = agentWallets[normalized] else {
            throw PerpsError.keyGenerationFailed
        }
        return wallet
    }

    // MARK: - Agent Wallet

    func createAgentWallet(masterAddress: String) async throws -> (agentAddress: String, vault: String) {
        let normalizedMaster = masterAddress.lowercased()
        if let existing = agentWallets[normalizedMaster] {
            return (existing.agentAddress, existing.vault)
        }

        // Generate a cryptographically secure secp256k1 private key.
        var privateKeyBytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, privateKeyBytes.count, &privateKeyBytes)
        guard result == errSecSuccess else { throw PerpsError.keyGenerationFailed }

        let privateKeyData = Data(privateKeyBytes)
        let vault = privateKeyData.hexString
        let agentAddress = try Secp256k1Helper.privateKeyToAddress(privateKeyData)

        let walletInfo = AgentWalletInfo(vault: vault, agentAddress: agentAddress, approveSignatures: [])
        agentWallets[normalizedMaster] = walletInfo
        saveToStorage()

        return (agentAddress, vault)
    }

    func getAgentWallet(address: String) -> AgentWalletInfo? {
        return agentWallets[address.lowercased()]
    }

    func hasAgentWallet(address: String) -> Bool {
        return agentWallets[address.lowercased()] != nil
    }

    func removeAgentWallet(address: String) {
        agentWallets.removeValue(forKey: address.lowercased())
        if currentAccount?.address.lowercased() == address.lowercased() { currentAccount = nil }
        if lastUsedAccount?.address.lowercased() == address.lowercased() { lastUsedAccount = nil }
        saveToStorage()
    }

    /// Store an approval signature for the agent wallet
    func addApproveSignature(address: String, signature: ApproveSignature) {
        guard var wallet = agentWallets[address.lowercased()] else { return }
        // Replace existing signature of the same type, or append
        wallet.approveSignatures.removeAll { $0.type == signature.type }
        wallet.approveSignatures.append(signature)
        agentWallets[address.lowercased()] = wallet
        saveToStorage()
    }

    // MARK: - Trading Settings

    func setFavoritedCoins(_ coins: [String]) {
        favoritedCoins = coins
        saveToStorage()
    }

    func setMarketSlippage(_ slippage: Double) {
        marketSlippage = max(0, min(1, slippage))
        saveToStorage()
    }

    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        saveToStorage()
    }

    func setQuoteUnit(_ unit: QuoteUnit) {
        quoteUnit = unit
        saveToStorage()
    }

    func setHasDoneNewUserProcess(_ done: Bool) {
        hasDoneNewUserProcess = done
        saveToStorage()
    }

    // MARK: - Markets API

    /// Fetch all supported perps markets from the API
    func loadMarkets() async {
        isLoadingMarkets = true
        defer { isLoadingMarkets = false }

        do {
            let rawMarkets: [RawPerpsMarket] = try await retryRequest {
                try await self.api.get("/v1/perps/markets")
            }
            markets = rawMarkets.map { $0.toPerpsMarket() }
            lastMarketsRefresh = Date()
            lastError = nil
        } catch {
            // On first load failure, keep existing data; only set error
            if markets.isEmpty {
                lastError = .apiFailed("Failed to load markets: \(error.localizedDescription)")
            }
            print("[PerpsManager] Failed to load markets: \(error)")
        }
    }

    /// Get a specific market by symbol
    func getMarket(symbol: String) -> PerpsMarket? {
        return markets.first { symbolsMatch($0.symbol, symbol) }
    }

    /// Get markets sorted by 24h volume (descending)
    func getMarketsByVolume() -> [PerpsMarket] {
        return markets.sorted { $0.volume24h > $1.volume24h }
    }

    /// Get favorited markets
    func getFavoritedMarkets() -> [PerpsMarket] {
        return markets.filter { market in
            favoritedCoins.contains { coin in
                market.symbol.uppercased().hasPrefix(coin.uppercased())
            }
        }
    }

    // MARK: - Positions API

    /// Fetch current open positions for the given address
    func loadPositions(address: String) async {
        isLoadingPositions = true
        defer { isLoadingPositions = false }

        do {
            let rawPositions: [RawPerpsPosition] = try await retryRequest {
                try await self.api.get("/v1/perps/positions", params: ["address": address])
            }
            positions = rawPositions.map { $0.toPerpsPosition() }
            lastPositionsRefresh = Date()
            lastError = nil
        } catch {
            if positions.isEmpty {
                lastError = .apiFailed("Failed to load positions: \(error.localizedDescription)")
            }
            print("[PerpsManager] Failed to load positions: \(error)")
        }
    }

    /// Get positions filtered by symbol
    func getPositions(symbol: String) -> [PerpsPosition] {
        return positions.filter { symbolsMatch($0.symbol, symbol) }
    }

    /// Total unrealized PnL across all positions
    var totalUnrealizedPnl: Double {
        return positions.reduce(0) { $0 + $1.unrealizedPnl }
    }

    /// Total margin used across all positions
    var totalMarginUsed: Double {
        return positions.reduce(0) { $0 + $1.margin }
    }

    /// Total notional value across all positions
    var totalNotionalValue: Double {
        return positions.reduce(0) { $0 + $1.notionalValue }
    }

    // MARK: - Orders API

    /// Fetch active orders for the given address
    func loadOrders(address: String) async {
        isLoadingOrders = true
        defer { isLoadingOrders = false }

        do {
            let rawOrders: [RawPerpsOrder] = try await retryRequest {
                try await self.api.get("/v1/perps/orders", params: ["address": address])
            }
            orders = rawOrders.map { $0.toPerpsOrder() }
            lastOrdersRefresh = Date()
            lastError = nil
        } catch {
            if orders.isEmpty {
                lastError = .apiFailed("Failed to load orders: \(error.localizedDescription)")
            }
            print("[PerpsManager] Failed to load orders: \(error)")
        }
    }

    /// Cancel a single order by ID
    func cancelOrder(orderId: String) async throws {
        guard let account = currentAccount else { throw PerpsError.noAccount }
        let agentWallet = try await ensureAgentWallet(address: account.address)

        let signature = try await signAction(
            agentWallet: agentWallet,
            action: "cancel",
            payload: ["order_id": orderId]
        )

        let _: PerpsAPIResponse<Bool> = try await api.post("/v1/perps/order/cancel", body: [
            "address": account.address,
            "agent_address": agentWallet.agentAddress,
            "order_id": orderId,
            "signature": signature
        ])

        // Optimistically remove the order from local state
        orders.removeAll { $0.id == orderId }

        // Refresh orders to get server-confirmed state
        await loadOrders(address: account.address)
    }

    /// Cancel all active orders, optionally filtered by symbol
    func cancelAllOrders(symbol: String? = nil) async throws {
        guard let account = currentAccount else { throw PerpsError.noAccount }
        let agentWallet = try await ensureAgentWallet(address: account.address)

        var payload: [String: Any] = [
            "address": account.address,
            "agent_address": agentWallet.agentAddress
        ]
        if let symbol = symbol {
            payload["symbol"] = symbol
        }

        let signature = try await signAction(
            agentWallet: agentWallet,
            action: "cancelAll",
            payload: symbol != nil ? ["symbol": symbol!] : [:]
        )
        payload["signature"] = signature

        let _: PerpsAPIResponse<Bool> = try await api.post("/v1/perps/order/cancel_all", body: payload)

        // Optimistically clear orders
        if let symbol = symbol {
            orders.removeAll { $0.symbol.uppercased() == symbol.uppercased() && $0.isCancellable }
        } else {
            orders.removeAll { $0.isCancellable }
        }

        await loadOrders(address: account.address)
    }

    // MARK: - Trading API

    /// Open a new perpetual position
    /// - Parameters:
    ///   - symbol: Trading pair symbol (e.g. "BTC-PERP")
    ///   - side: Long or short
    ///   - size: Position size in base currency
    ///   - leverage: Leverage multiplier
    ///   - orderType: Type of order to place
    ///   - price: Limit price (required for limit/stop-limit orders)
    ///   - triggerPrice: Trigger price (required for stop orders)
    ///   - reduceOnly: Whether this order only reduces an existing position
    /// - Returns: The created order
    @discardableResult
    func openPosition(
        symbol: String,
        side: PositionSide,
        size: Double,
        leverage: Double,
        orderType: PerpsOrderType = .market,
        price: Double? = nil,
        triggerPrice: Double? = nil,
        reduceOnly: Bool = false
    ) async throws -> PerpsOrder {
        guard let account = currentAccount else { throw PerpsError.noAccount }
        let agentWallet = try await ensureAgentWallet(address: account.address)

        let normalizedSymbol = normalizeTradingSymbol(symbol)

        // Validate inputs
        guard size > 0 else { throw PerpsError.invalidParameter("Size must be greater than 0") }
        guard leverage >= 1 else { throw PerpsError.invalidParameter("Leverage must be at least 1x") }

        if let market = getMarket(symbol: normalizedSymbol) {
            guard Int(leverage) <= market.maxLeverage else {
                throw PerpsError.invalidParameter("Leverage exceeds maximum \(market.maxLeverage)x for \(normalizedSymbol)")
            }
        }

        if orderType == .limit || orderType == .stopLimit {
            guard price != nil else {
                throw PerpsError.invalidParameter("Price is required for \(orderType.displayName) orders")
            }
        }

        if orderType == .stopLimit || orderType == .stopMarket {
            guard triggerPrice != nil else {
                throw PerpsError.invalidParameter("Trigger price is required for \(orderType.displayName) orders")
            }
        }

        // Build order payload
        var orderPayload: [String: Any] = [
            "symbol": normalizedSymbol,
            "side": side.rawValue,
            "size": size,
            "leverage": leverage,
            "order_type": orderType.rawValue,
            "reduce_only": reduceOnly,
            "slippage": marketSlippage
        ]
        if let price = price { orderPayload["price"] = price }
        if let triggerPrice = triggerPrice { orderPayload["trigger_price"] = triggerPrice }

        // Sign the order with agent wallet
        let signature = try await signAction(
            agentWallet: agentWallet,
            action: "order",
            payload: orderPayload
        )

        orderPayload["address"] = account.address
        orderPayload["agent_address"] = agentWallet.agentAddress
        orderPayload["signature"] = signature

        let response: RawPerpsOrder = try await api.post("/v1/perps/order", body: orderPayload)
        let order = response.toPerpsOrder()

        // Add to local orders list
        orders.insert(order, at: 0)

        // Refresh positions and orders for updated state
        Task {
            await loadPositions(address: account.address)
            await loadOrders(address: account.address)
        }

        return order
    }

    /// Close an existing position (fully or partially)
    /// - Parameters:
    ///   - symbol: The symbol of the position to close
    ///   - size: Size to close (nil = close entire position)
    @discardableResult
    func closePosition(symbol: String, size: Double? = nil) async throws -> PerpsOrder {
        guard let account = currentAccount else { throw PerpsError.noAccount }
        _ = try await ensureAgentWallet(address: account.address)

        let normalizedSymbol = normalizeTradingSymbol(symbol)

        // Find the open position for this symbol
        guard let position = positions.first(where: { symbolsMatch($0.symbol, normalizedSymbol) }) else {
            throw PerpsError.noPosition(normalizedSymbol)
        }

        let closeSize = size ?? position.size
        guard closeSize > 0 && closeSize <= position.size else {
            throw PerpsError.invalidParameter("Close size must be between 0 and \(position.size)")
        }

        // Close by placing an opposite-side market order with reduceOnly
        let closeSide: PositionSide = position.side == .long ? .short : .long

        return try await openPosition(
            symbol: normalizedSymbol,
            side: closeSide,
            size: closeSize,
            leverage: position.leverage,
            orderType: .market,
            reduceOnly: true
        )
    }

    /// Modify an existing position's leverage or margin
    /// - Parameters:
    ///   - symbol: The symbol of the position to modify
    ///   - newLeverage: New leverage multiplier (nil to keep current)
    ///   - newMargin: New margin amount (nil to keep current)
    func modifyPosition(symbol: String, newLeverage: Double? = nil, newMargin: Double? = nil) async throws {
        guard let account = currentAccount else { throw PerpsError.noAccount }
        let agentWallet = try await ensureAgentWallet(address: account.address)

        let normalizedSymbol = normalizeTradingSymbol(symbol)

        guard positions.contains(where: { symbolsMatch($0.symbol, normalizedSymbol) }) else {
            throw PerpsError.noPosition(normalizedSymbol)
        }

        guard newLeverage != nil || newMargin != nil else {
            throw PerpsError.invalidParameter("Must specify newLeverage or newMargin to modify")
        }

        var payload: [String: Any] = [
            "address": account.address,
            "agent_address": agentWallet.agentAddress,
            "symbol": normalizedSymbol
        ]
        if let newLeverage = newLeverage {
            guard newLeverage >= 1 else {
                throw PerpsError.invalidParameter("Leverage must be at least 1x")
            }
            payload["leverage"] = newLeverage
        }
        if let newMargin = newMargin {
            guard newMargin > 0 else {
                throw PerpsError.invalidParameter("Margin must be greater than 0")
            }
            payload["margin"] = newMargin
        }

        let signature = try await signAction(
            agentWallet: agentWallet,
            action: "modifyPosition",
            payload: payload
        )
        payload["signature"] = signature

        let _: PerpsAPIResponse<Bool> = try await api.post("/v1/perps/position/modify", body: payload)

        // Refresh positions to reflect changes
        await loadPositions(address: account.address)
    }

    // MARK: - Auto-Refresh Timers

    /// Start the auto-refresh timers for markets (5s) and account data (10s)
    func startAutoRefresh() {
        stopAutoRefresh()

        // Markets refresh every 5 seconds
        marketsRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadMarkets()
            }
        }

        // Positions & orders refresh every 10 seconds
        accountDataRefreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let account = self.currentAccount else { return }
                await self.loadPositions(address: account.address)
                await self.loadOrders(address: account.address)
            }
        }
    }

    /// Stop all auto-refresh timers
    func stopAutoRefresh() {
        marketsRefreshTimer?.invalidate()
        marketsRefreshTimer = nil
        accountDataRefreshTimer?.invalidate()
        accountDataRefreshTimer = nil
    }

    /// Refresh all data (markets, positions, orders) immediately
    func refreshAllData() async {
        isLoading = true
        defer { isLoading = false }

        // Load markets in parallel with account data
        async let marketsTask: () = loadMarkets()

        if let account = currentAccount {
            async let positionsTask: () = loadPositions(address: account.address)
            async let ordersTask: () = loadOrders(address: account.address)
            _ = await (marketsTask, positionsTask, ordersTask)
        } else {
            await marketsTask
        }
    }

    // MARK: - Agent Wallet Signing

    /// Sign a trading action with the agent wallet's private key
    private func signAction(agentWallet: AgentWalletInfo, action: String, payload: [String: Any]) async throws -> String {
        guard let privateKey = Data(hexString: agentWallet.vault) else {
            throw PerpsError.signingFailed("Invalid agent private key")
        }

        let canonicalPayloadData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        var signable = Data(action.utf8)
        signable.append(Data([0x3A])) // ':'
        signable.append(canonicalPayloadData)

        let digest = Keccak256.hash(data: signable)
        let signature = try Secp256k1Helper.sign(hash: digest, privateKey: privateKey)

        var rawSignature = Data()
        rawSignature.append(signature.r)
        rawSignature.append(signature.s)
        rawSignature.append(UInt8(signature.recid + 27))

        return "0x" + rawSignature.hexString
    }

    // MARK: - Symbol Utils

    private func normalizeTradingSymbol(_ symbol: String) -> String {
        let cleaned = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.uppercased().hasSuffix("-PERP") {
            return cleaned.uppercased()
        }
        return "\(cleaned.uppercased())-PERP"
    }

    private func symbolsMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalizeTradingSymbol(lhs) == normalizeTradingSymbol(rhs)
    }

    // MARK: - Retry Logic

    /// Execute an async request with exponential backoff retry
    private func retryRequest<T>(maxAttempts: Int? = nil, operation: @escaping () async throws -> T) async throws -> T {
        let attempts = maxAttempts ?? maxRetryAttempts
        var lastError: Error?

        for attempt in 0..<attempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry on client errors (4xx) - only on server/network errors
                if let apiError = error as? OpenAPIError,
                   case .requestFailed(let statusCode) = apiError,
                   (400..<500).contains(statusCode) {
                    throw error
                }

                if attempt < attempts - 1 {
                    let delay = retryBaseDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? PerpsError.apiFailed("Request failed after \(attempts) attempts")
    }

    // MARK: - Storage

    private func loadFromStorage() {
        var decodedStore: PerpsStore?
        if let data = storage.getData(forKey: storageKey) {
            decodedStore = try? JSONDecoder().decode(PerpsStore.self, from: data)
        }

        currentAccount = decodedStore?.currentAccount
        lastUsedAccount = decodedStore?.lastUsedAccount
        hasDoneNewUserProcess = decodedStore?.hasDoneNewUserProcess ?? false
        favoritedCoins = decodedStore?.favoritedCoins ?? ["BTC", "ETH", "SOL"]
        marketSlippage = decodedStore?.marketSlippage ?? 0.08
        soundEnabled = decodedStore?.soundEnabled ?? true
        quoteUnit = decodedStore?.quoteUnit ?? .base

        let preferences = Dictionary(uniqueKeysWithValues: (decodedStore?.agentPreferences ?? [:]).map {
            ($0.key.lowercased(), $0.value)
        })
        let legacyWallets = Dictionary(uniqueKeysWithValues: (decodedStore?.legacyAgentWallets ?? [:]).map {
            ($0.key.lowercased(), $0.value)
        })
        let storedVaults = Dictionary(uniqueKeysWithValues: loadAgentVaultsFromKeychain().map {
            ($0.key.lowercased(), $0.value)
        })

        var rebuiltWallets: [String: AgentWalletInfo] = [:]
        var migratedVaults = storedVaults
        var didMigrate = false

        let allAddresses = Set(preferences.keys).union(legacyWallets.keys).union(storedVaults.keys)
        for address in allAddresses {
            let normalized = address.lowercased()
            let preference = preferences[normalized] ?? {
                if let legacy = legacyWallets[normalized] {
                    return AgentWalletPreference(
                        agentAddress: legacy.agentAddress,
                        approveSignatures: legacy.approveSignatures
                    )
                }
                return AgentWalletPreference(agentAddress: "", approveSignatures: [])
            }()

            var vault = storedVaults[normalized]
            if vault == nil, let legacy = legacyWallets[normalized] {
                vault = legacy.vault
                migratedVaults[normalized] = legacy.vault
                didMigrate = true
            }

            guard let resolvedVault = vault, !resolvedVault.isEmpty else { continue }
            rebuiltWallets[normalized] = AgentWalletInfo(
                vault: resolvedVault,
                agentAddress: preference.agentAddress,
                approveSignatures: preference.approveSignatures
            )
        }

        agentWallets = rebuiltWallets

        if didMigrate {
            saveAgentVaultsToKeychain(migratedVaults)
            saveToStorage()
        }
    }

    private func saveToStorage() {
        let preferences = Dictionary(uniqueKeysWithValues: agentWallets.map { key, value in
            (key.lowercased(), AgentWalletPreference(agentAddress: value.agentAddress, approveSignatures: value.approveSignatures))
        })

        let store = PerpsStore(
            currentAccount: currentAccount,
            lastUsedAccount: lastUsedAccount,
            hasDoneNewUserProcess: hasDoneNewUserProcess,
            favoritedCoins: favoritedCoins,
            marketSlippage: marketSlippage,
            soundEnabled: soundEnabled,
            quoteUnit: quoteUnit,
            agentPreferences: preferences,
            legacyAgentWallets: nil
        )
        if let data = try? JSONEncoder().encode(store) {
            storage.setData(data, forKey: storageKey)
        }

        let vaultMap = Dictionary(uniqueKeysWithValues: agentWallets.map { ($0.key.lowercased(), $0.value.vault) })
        saveAgentVaultsToKeychain(vaultMap)
    }

    private func loadAgentVaultsFromKeychain() -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: perpsKeychainService,
            kSecAttrAccount as String: agentVaultsAccountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private func saveAgentVaultsToKeychain(_ vaults: [String: String]) {
        guard let data = try? JSONEncoder().encode(vaults) else { return }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: perpsKeychainService,
            kSecAttrAccount as String: agentVaultsAccountKey
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private struct PerpsStore: Codable {
        let currentAccount: PerpsAccount?
        let lastUsedAccount: PerpsAccount?
        let hasDoneNewUserProcess: Bool
        let favoritedCoins: [String]
        let marketSlippage: Double
        let soundEnabled: Bool
        let quoteUnit: QuoteUnit
        let agentPreferences: [String: AgentWalletPreference]?
        let legacyAgentWallets: [String: AgentWalletInfo]?

        enum CodingKeys: String, CodingKey {
            case currentAccount
            case lastUsedAccount
            case hasDoneNewUserProcess
            case favoritedCoins
            case marketSlippage
            case soundEnabled
            case quoteUnit
            case agentPreferences
            case legacyAgentWallets = "agentWallets"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(currentAccount, forKey: .currentAccount)
            try c.encode(lastUsedAccount, forKey: .lastUsedAccount)
            try c.encode(hasDoneNewUserProcess, forKey: .hasDoneNewUserProcess)
            try c.encode(favoritedCoins, forKey: .favoritedCoins)
            try c.encode(marketSlippage, forKey: .marketSlippage)
            try c.encode(soundEnabled, forKey: .soundEnabled)
            try c.encode(quoteUnit, forKey: .quoteUnit)
            try c.encode(agentPreferences, forKey: .agentPreferences)
        }
    }
}

// MARK: - PerpsError

enum PerpsError: LocalizedError {
    case noAccount
    case noAgentWallet
    case keyGenerationFailed
    case tradingFailed(String)
    case apiFailed(String)
    case invalidParameter(String)
    case noPosition(String)
    case signingFailed(String)
    case orderRejected(String)

    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "No perps account configured. Please connect a wallet first."
        case .noAgentWallet:
            return "No agent wallet found. Please create an agent wallet to trade."
        case .keyGenerationFailed:
            return "Failed to generate agent wallet key"
        case .tradingFailed(let msg):
            return "Trading failed: \(msg)"
        case .apiFailed(let msg):
            return "API request failed: \(msg)"
        case .invalidParameter(let msg):
            return "Invalid parameter: \(msg)"
        case .noPosition(let symbol):
            return "No open position found for \(symbol)"
        case .signingFailed(let msg):
            return "Transaction signing failed: \(msg)"
        case .orderRejected(let msg):
            return "Order rejected: \(msg)"
        }
    }
}
