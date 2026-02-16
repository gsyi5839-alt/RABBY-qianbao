import Foundation
import Combine

// MARK: - Data Models

/// 自定义测试网基础信息（对应扩展的 TestnetChainBase）
struct TestnetChainBase: Codable, Equatable {
    let id: Int                  // 链 ID
    let name: String             // 链名称
    let nativeTokenSymbol: String // 原生代币符号（如 ETH）
    let rpcUrl: String           // RPC URL
    var scanLink: String?        // 可选：区块浏览器 URL

    init(id: Int, name: String, nativeTokenSymbol: String, rpcUrl: String, scanLink: String? = nil) {
        self.id = id
        self.name = name
        self.nativeTokenSymbol = nativeTokenSymbol
        self.rpcUrl = rpcUrl
        self.scanLink = scanLink
    }
}

/// 完整的测试网链信息（对应扩展的 TestnetChain）
struct TestnetChain: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let nativeTokenSymbol: String
    let rpcUrl: String
    let scanLink: String
    let nativeTokenAddress: String  // 原生代币地址（如 "custom_999999"）
    let hex: String                 // 链 ID 的十六进制表示
    let network: String             // 网络标识符（等于 id 字符串）
    let enumValue: String           // 链枚举值（如 "CUSTOM_999999"）
    let serverId: String            // 服务器 ID（如 "custom_999999"）
    let nativeTokenLogo: String     // 原生代币 logo URL
    let nativeTokenDecimals: Int    // 原生代币精度（默认 18）
    let logo: String                // 链 logo URL
    let whiteLogo: String?          // 可选：白色 logo URL
    let isTestnet: Bool             // 是否为测试网
    let needEstimateGas: Bool       // 是否需要估算 gas
    let severity: Int               // 严重程度（默认 0）

    // 从基础信息创建完整链
    init(from base: TestnetChainBase, logos: TestnetChainLogos? = nil) {
        self.id = base.id
        self.name = base.name
        self.nativeTokenSymbol = base.nativeTokenSymbol
        self.rpcUrl = base.rpcUrl
        self.scanLink = base.scanLink ?? ""
        self.nativeTokenAddress = "custom_\(base.id)"
        self.hex = String(format: "0x%x", base.id)
        self.network = String(base.id)
        self.enumValue = "CUSTOM_\(base.id)"
        self.serverId = "custom_\(base.id)"
        self.nativeTokenDecimals = 18
        self.isTestnet = true
        self.needEstimateGas = false
        self.severity = 0
        self.whiteLogo = nil

        // Logo 优先使用 API 返回的，否则生成默认 SVG
        if let logos = logos, let chainLogo = logos.chain_logo_url {
            self.logo = chainLogo
            self.nativeTokenLogo = logos.token_logo_url ?? CustomTestnetManager.generateDefaultLogo(name: base.name)
        } else {
            self.logo = CustomTestnetManager.generateDefaultLogo(name: base.name)
            self.nativeTokenLogo = CustomTestnetManager.generateDefaultLogo(name: base.name)
        }
    }
}

/// 自定义测试网 token 基础信息（对应扩展的 CustomTestnetTokenBase）
struct CustomTestnetTokenBase: Codable, Equatable, Hashable {
    let id: String        // Token 地址（原生代币为 nil 或 nativeTokenAddress）
    let chainId: Int      // 链 ID
    let symbol: String    // Token 符号
    let decimals: Int     // Token 精度

    init(id: String, chainId: Int, symbol: String, decimals: Int) {
        self.id = id
        self.chainId = chainId
        self.symbol = symbol
        self.decimals = decimals
    }
}

/// 包含余额的 token 信息（对应扩展的 CustomTestnetToken）
struct CustomTestnetToken: Codable, Equatable {
    let id: String
    let chainId: Int
    let symbol: String
    let decimals: Int
    let amount: Double      // 格式化后的余额
    let rawAmount: String   // 原始余额（wei）
    var logo: String?       // 可选：token logo URL

    init(id: String, chainId: Int, symbol: String, decimals: Int, amount: Double, rawAmount: String, logo: String? = nil) {
        self.id = id
        self.chainId = chainId
        self.symbol = symbol
        self.decimals = decimals
        self.amount = amount
        self.rawAmount = rawAmount
        self.logo = logo
    }
}

/// 测试网 logo 缓存（从 debank API 获取）
struct TestnetChainLogos: Codable {
    let chain_logo_url: String?
    let token_logo_url: String?
}

/// 测试网错误类型
enum TestnetError: Error, Equatable {
    case alreadyAdded      // 测试网已添加
    case alreadySupported  // 链已被 Rabby 原生支持
    case invalidRPC(String) // RPC 无效
    case chainIdMismatch   // RPC 返回的 chainId 与输入不匹配
    case unknown(String)   // 其他错误

    var key: String {
        switch self {
        case .alreadyAdded, .alreadySupported:
            return "id"
        case .invalidRPC, .chainIdMismatch:
            return "rpcUrl"
        case .unknown:
            return "unknown"
        }
    }

    var message: String {
        switch self {
        case .alreadyAdded:
            return "You've already added this chain"
        case .alreadySupported:
            return "Chain already integrated by Rabby Wallet"
        case .invalidRPC(let detail):
            return "RPC invalid or currently unavailable: \(detail)"
        case .chainIdMismatch:
            return "RPC does not match the chainID"
        case .unknown(let msg):
            return msg
        }
    }

    var status: String? {
        switch self {
        case .alreadyAdded:
            return "alreadyAdded"
        case .alreadySupported:
            return "alreadySupported"
        default:
            return nil
        }
    }
}

// MARK: - Custom Testnet Manager

/// 自定义测试网管理器（对应扩展的 CustomTestnetService）
@MainActor
class CustomTestnetManager: ObservableObject {
    static let shared = CustomTestnetManager()

    // MARK: - Published Properties

    @Published private(set) var customTestnets: [Int: TestnetChain] = [:]  // chainId -> TestnetChain
    @Published private(set) var customTokens: [CustomTestnetTokenBase] = []
    @Published private(set) var logos: [Int: TestnetChainLogos] = [:]  // chainId -> logos

    // MARK: - Private Properties

    private let storageManager = StorageManager.shared
    private let networkManager = NetworkManager.shared

    private let customTestnetKey = "rabby_custom_testnet"
    private let customTokenListKey = "rabby_custom_token_list"
    private let logosKey = "rabby_testnet_logos"
    private let logosUpdatedAtKey = "rabby_testnet_logos_updated_at"

    private var logosUpdatedAt: TimeInterval = 0

    // Logo 缓存时间（24 小时，对齐扩展钱包）
    private let logoCacheDuration: TimeInterval = 24 * 60 * 60

    // MARK: - Initialization

    private init() {
        loadCustomTestnets()
        loadCustomTokens()
        loadLogos()

        // 异步加载 logos（如果需要更新）
        Task {
            await fetchLogosIfNeeded()
        }
    }

    // MARK: - Public Methods - Core Testnet Management

    /// 添加自定义测试网（对应扩展的 add）
    /// - Parameter chain: 测试网基础信息
    /// - Returns: 成功返回完整链信息，失败返回错误
    func add(_ chain: TestnetChainBase) async -> Result<TestnetChain, TestnetError> {
        return await _update(chain, isAdd: true)
    }

    /// 更新自定义测试网（对应扩展的 update）
    /// - Parameter chain: 测试网基础信息
    /// - Returns: 成功返回完整链信息，失败返回错误
    func update(_ chain: TestnetChainBase) async -> Result<TestnetChain, TestnetError> {
        return await _update(chain, isAdd: false)
    }

    /// 内部更新方法
    private func _update(_ chain: TestnetChainBase, isAdd: Bool) async -> Result<TestnetChain, TestnetError> {
        // 1. 检查链是否已存在
        if isAdd {
            // 检查是否已添加
            if customTestnets[chain.id] != nil {
                return .failure(.alreadyAdded)
            }

            // 检查是否为原生支持的链
            if ChainManager.shared.getChain(id: chain.id) != nil {
                return .failure(.alreadySupported)
            }
        }

        // 2. 验证 RPC URL（调用 eth_chainId）
        let rpcValidation = await validateRPC(url: chain.rpcUrl, expectedChainId: chain.id)
        switch rpcValidation {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }

        // 3. 创建完整的测试网链
        let testnetChain = TestnetChain(from: chain, logos: logos[chain.id])

        // 4. 保存到存储
        customTestnets[chain.id] = testnetChain
        saveCustomTestnets()

        // 5. 同步到 ChainManager（对齐扩展：新增/更新后链列表立即可见）
        ChainManager.shared.refreshCustomTestnets()

        print("[CustomTestnetManager] ✅ \(isAdd ? "Added" : "Updated") custom testnet: \(chain.name) (chainId: \(chain.id))")

        return .success(testnetChain)
    }

    /// 删除自定义测试网（对应扩展的 remove）
    /// - Parameter chainId: 链 ID
    func remove(chainId: Int) {
        customTestnets.removeValue(forKey: chainId)

        // 删除该链上的所有自定义 token
        customTokens.removeAll { $0.chainId == chainId }

        saveCustomTestnets()
        saveCustomTokens()

        // 对齐扩展：删除后链列表立即刷新
        ChainManager.shared.refreshCustomTestnets()

        print("[CustomTestnetManager] ✅ Removed custom testnet: chainId \(chainId)")
    }

    /// 获取所有自定义测试网列表（对应扩展的 getList）
    /// - Returns: 测试网数组
    func getList() -> [TestnetChain] {
        return Array(customTestnets.values).sorted { $0.id < $1.id }
    }

    /// 获取指定链的信息
    /// - Parameter chainId: 链 ID
    /// - Returns: 测试网链信息，如果不存在则返回 nil
    func getChain(chainId: Int) -> TestnetChain? {
        return customTestnets[chainId]
    }

    // MARK: - Public Methods - Custom Token Management

    /// 添加自定义 token（对应扩展的 addToken）
    /// - Parameter token: Token 基础信息
    func addToken(_ token: CustomTestnetTokenBase) throws {
        if hasToken(id: token.id, chainId: token.chainId) {
            throw TestnetError.unknown("Token already added")
        }

        customTokens.append(token)
        saveCustomTokens()

        print("[CustomTestnetManager] ✅ Added custom token: \(token.symbol) on chain \(token.chainId)")
    }

    /// 删除自定义 token（对应扩展的 removeToken）
    /// - Parameter token: Token 基础信息
    func removeToken(_ token: CustomTestnetTokenBase) {
        customTokens.removeAll { isSameTestnetToken($0, token) }
        saveCustomTokens()

        print("[CustomTestnetManager] ✅ Removed custom token: \(token.symbol) on chain \(token.chainId)")
    }

    /// 检查 token 是否存在（对应扩展的 hasToken）
    /// - Parameters:
    ///   - id: Token 地址
    ///   - chainId: 链 ID
    /// - Returns: 是否存在
    func hasToken(id: String, chainId: Int) -> Bool {
        return customTokens.contains { isSameTestnetToken($0, CustomTestnetTokenBase(id: id, chainId: chainId, symbol: "", decimals: 0)) }
    }

    /// 获取指定链的所有 token（对应扩展的 getTokenList）
    /// - Parameters:
    ///   - address: 用户地址（用于查询余额）
    ///   - chainId: 链 ID，如果为 nil 则返回所有链的 token
    /// - Returns: Token 列表
    func getTokenList(address: String, chainId: Int? = nil) -> [CustomTestnetTokenBase] {
        var tokens = customTokens

        // 过滤指定链
        if let chainId = chainId {
            tokens = tokens.filter { $0.chainId == chainId }
        }

        // 添加原生代币
        let nativeTokens = customTestnets.values.compactMap { chain -> CustomTestnetTokenBase? in
            if let chainId = chainId, chain.id != chainId {
                return nil
            }
            return CustomTestnetTokenBase(
                id: chain.nativeTokenAddress,
                chainId: chain.id,
                symbol: chain.nativeTokenSymbol,
                decimals: chain.nativeTokenDecimals
            )
        }

        return nativeTokens + tokens
    }

    // MARK: - Private Methods - RPC Validation

    /// 验证 RPC URL（对应扩展的验证逻辑）
    /// - Parameters:
    ///   - url: RPC URL
    ///   - expectedChainId: 期望的链 ID
    /// - Returns: 成功返回 Void，失败返回错误
    private func validateRPC(url: String, expectedChainId: Int) async -> Result<Void, TestnetError> {
        // 1. 检查 URL 格式
        guard let rpcURL = URL(string: url) else {
            return .failure(.invalidRPC("Invalid URL format"))
        }

        // 2. 调用 eth_chainId
        do {
            let chainIdHex: String = try await networkManager.sendRPCRequest(
                method: "eth_chainId",
                params: [],
                rpcURL: rpcURL,
                responseType: String.self,
                timeout: 6000  // 6 秒超时，对齐扩展钱包
            )

            // 3. 解析返回的 chainId（十六进制）
            guard let returnedChainId = Int(chainIdHex.replacingOccurrences(of: "0x", with: ""), radix: 16) else {
                return .failure(.invalidRPC("Invalid chainId format: \(chainIdHex)"))
            }

            // 4. 检查是否匹配
            if returnedChainId != expectedChainId {
                print("[CustomTestnetManager] ❌ RPC chainId mismatch: expected \(expectedChainId), got \(returnedChainId)")
                return .failure(.chainIdMismatch)
            }

            print("[CustomTestnetManager] ✅ RPC validation successful for chain \(expectedChainId)")
            return .success(())

        } catch {
            print("[CustomTestnetManager] ❌ RPC validation failed: \(error.localizedDescription)")
            return .failure(.invalidRPC(error.localizedDescription))
        }
    }

    // MARK: - Private Methods - Logo Management

    /// 获取 logo（如果需要则从 API 拉取）
    private func fetchLogosIfNeeded() async {
        // 检查是否需要更新（24 小时缓存）
        let now = Date().timeIntervalSince1970
        if now < logosUpdatedAt + logoCacheDuration {
            print("[CustomTestnetManager] 📦 Using cached logos (updated at \(Date(timeIntervalSince1970: logosUpdatedAt)))")
            return
        }

        // 从 debank API 拉取
        await fetchLogos()
    }

    /// 从 debank API 拉取 logo（对应扩展的 fetchLogos）
    private func fetchLogos() async {
        do {
            // debank API: https://static.debank.com/supported_testnet_chains.json
            guard let url = URL(string: "https://static.debank.com/supported_testnet_chains.json") else {
                print("[CustomTestnetManager] ❌ Invalid logo API URL")
                return
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([String: TestnetChainLogos].self, from: data)

            // 转换为 [Int: TestnetChainLogos]
            var newLogos: [Int: TestnetChainLogos] = [:]
            for (key, value) in decoded {
                if let chainId = Int(key) {
                    newLogos[chainId] = value
                }
            }

            logos = newLogos
            logosUpdatedAt = Date().timeIntervalSince1970

            saveLogos()
            saveLogosUpdatedAt()

            print("[CustomTestnetManager] ✅ Fetched \(newLogos.count) testnet logos from debank")

            // 更新已存在的测试网的 logo
            syncLogosToTestnets()

        } catch {
            print("[CustomTestnetManager] ❌ Failed to fetch logos: \(error.localizedDescription)")
        }
    }

    /// 将 logo 同步到已有的测试网
    private func syncLogosToTestnets() {
        for (chainId, chain) in customTestnets {
            if logos[chainId] != nil {
                // 重新创建 TestnetChain 以更新 logo
                let base = TestnetChainBase(
                    id: chain.id,
                    name: chain.name,
                    nativeTokenSymbol: chain.nativeTokenSymbol,
                    rpcUrl: chain.rpcUrl,
                    scanLink: chain.scanLink.isEmpty ? nil : chain.scanLink
                )
                customTestnets[chainId] = TestnetChain(from: base, logos: logos[chainId])
            }
        }
        saveCustomTestnets()

        // logos 变更会影响链展示；刷新一次链列表即可
        ChainManager.shared.refreshCustomTestnets()
    }

    /// 生成默认 SVG logo（对齐扩展钱包）
    nonisolated static func generateDefaultLogo(name: String) -> String {
        let firstLetter = name.trimmingCharacters(in: .whitespaces).prefix(1).uppercased()
        let encoded = firstLetter.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "?"

        return """
        data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 28 28'>\
        <circle cx='14' cy='14' r='14' fill='%236A7587'></circle>\
        <text x='14' y='15' dominant-baseline='middle' text-anchor='middle' fill='white' font-size='16' font-weight='500'>\
        \(encoded)\
        </text></svg>
        """
    }

    // MARK: - Private Methods - Storage

    private func loadCustomTestnets() {
        if let data = storageManager.getData(forKey: customTestnetKey),
           let decoded = try? JSONDecoder().decode([Int: TestnetChain].self, from: data) {
            customTestnets = decoded
            print("[CustomTestnetManager] 📦 Loaded \(customTestnets.count) custom testnets")
        }
    }

    private func saveCustomTestnets() {
        if let encoded = try? JSONEncoder().encode(customTestnets) {
            storageManager.setData(encoded, forKey: customTestnetKey)
        }
    }

    private func loadCustomTokens() {
        if let data = storageManager.getData(forKey: customTokenListKey),
           let decoded = try? JSONDecoder().decode([CustomTestnetTokenBase].self, from: data) {
            customTokens = decoded
            print("[CustomTestnetManager] 📦 Loaded \(customTokens.count) custom tokens")
        }
    }

    private func saveCustomTokens() {
        if let encoded = try? JSONEncoder().encode(customTokens) {
            storageManager.setData(encoded, forKey: customTokenListKey)
        }
    }

    private func loadLogos() {
        if let data = storageManager.getData(forKey: logosKey),
           let decoded = try? JSONDecoder().decode([Int: TestnetChainLogos].self, from: data) {
            logos = decoded
            print("[CustomTestnetManager] 📦 Loaded \(logos.count) testnet logos")
        }

        if let data = storageManager.getData(forKey: logosUpdatedAtKey),
           let timestamp = try? JSONDecoder().decode(TimeInterval.self, from: data) {
            logosUpdatedAt = timestamp
        }
    }

    private func saveLogos() {
        if let encoded = try? JSONEncoder().encode(logos) {
            storageManager.setData(encoded, forKey: logosKey)
        }
    }

    private func saveLogosUpdatedAt() {
        if let encoded = try? JSONEncoder().encode(logosUpdatedAt) {
            storageManager.setData(encoded, forKey: logosUpdatedAtKey)
        }
    }

    // MARK: - Public Methods - Utility

    /// 获取统计信息（用于调试）
    func getStatistics() -> TestnetStatistics {
        return TestnetStatistics(
            totalCustomTestnets: customTestnets.count,
            totalCustomTokens: customTokens.count,
            cachedLogos: logos.count,
            logosLastUpdated: logosUpdatedAt > 0 ? Date(timeIntervalSince1970: logosUpdatedAt) : nil
        )
    }
}

// MARK: - Supporting Functions

/// 判断两个测试网 token 是否相同
private func isSameTestnetToken(_ a: CustomTestnetTokenBase, _ b: CustomTestnetTokenBase) -> Bool {
    return a.id.lowercased() == b.id.lowercased() && a.chainId == b.chainId
}

// MARK: - Supporting Types

struct TestnetStatistics {
    let totalCustomTestnets: Int
    let totalCustomTokens: Int
    let cachedLogos: Int
    let logosLastUpdated: Date?

    var description: String {
        """
        CustomTestnetManager Statistics:
        - Total Custom Testnets: \(totalCustomTestnets)
        - Total Custom Tokens: \(totalCustomTokens)
        - Cached Logos: \(cachedLogos)
        - Logos Last Updated: \(logosLastUpdated?.description ?? "Never")
        """
    }
}
