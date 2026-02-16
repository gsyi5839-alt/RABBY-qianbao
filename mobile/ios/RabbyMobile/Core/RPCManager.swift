import Foundation
import Combine

/// RPC 配置项（对应扩展的 RPCItem）
struct RPCItem: Codable, Equatable {
    let url: String         // RPC URL
    var enable: Bool        // 是否启用
    var alias: String?      // 可选：RPC 别名（如 "Infura"）

    init(url: String, enable: Bool = true, alias: String? = nil) {
        self.url = url
        self.enable = enable
        self.alias = alias
    }
}

/// RPC 状态缓存
struct RPCStatus: Codable {
    let expireAt: TimeInterval  // 过期时间
    let available: Bool         // 是否可用
    let lastPingAt: TimeInterval  // 上次测试时间

    init(expireAt: TimeInterval, available: Bool, lastPingAt: TimeInterval = Date().timeIntervalSince1970) {
        self.expireAt = expireAt
        self.available = available
        self.lastPingAt = lastPingAt
    }

    var isExpired: Bool {
        Date().timeIntervalSince1970 >= expireAt
    }
}

/// RPC Manager - 自定义 RPC 管理器
/// 对应扩展钱包的 RPCService (src/background/service/rpc.ts)
@MainActor
class RPCManager: ObservableObject {
    static let shared = RPCManager()

    // MARK: - Published Properties

    @Published private(set) var customRPCs: [Int: RPCItem] = [:]  // chainId -> RPCItem

    // MARK: - Private Properties

    private var rpcStatusCache: [Int: RPCStatus] = [:]  // chainId -> 状态缓存
    private let storageManager = StorageManager.shared
    private let session: URLSession  // ← 直接使用 URLSession 避免循环依赖

    private let customRPCKey = "rabby_custom_rpc"
    private let statusCacheKey = "rabby_rpc_status_cache"

    // RPC 状态缓存时间（60 秒，对齐扩展钱包）
    private let statusCacheDuration: TimeInterval = 60

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        loadCustomRPCs()
        loadStatusCache()
    }

    // MARK: - Public Methods - Core RPC Management

    /// 设置自定义 RPC（对应扩展的 setRPC）
    /// - Parameters:
    ///   - chainId: 链 ID
    ///   - url: RPC URL
    ///   - alias: 可选的别名
    func setRPC(chainId: Int, url: String, alias: String? = nil) {
        let rpcItem = customRPCs[chainId]
            ? RPCItem(url: url, enable: customRPCs[chainId]!.enable, alias: alias)
            : RPCItem(url: url, enable: true, alias: alias)

        customRPCs[chainId] = rpcItem

        // 清除该链的状态缓存
        rpcStatusCache.removeValue(forKey: chainId)

        saveCustomRPCs()
        saveStatusCache()

        print("[RPCManager] ✅ Set custom RPC for chain \(chainId): \(url)")
    }

    /// 启用/禁用自定义 RPC（对应扩展的 setRPCEnable）
    /// - Parameters:
    ///   - chainId: 链 ID
    ///   - enable: 是否启用
    func setRPCEnable(chainId: Int, enable: Bool) {
        guard var rpcItem = customRPCs[chainId] else {
            print("[RPCManager] ⚠️ No custom RPC found for chain \(chainId)")
            return
        }

        rpcItem.enable = enable
        customRPCs[chainId] = rpcItem
        saveCustomRPCs()

        print("[RPCManager] ✅ \(enable ? "Enabled" : "Disabled") custom RPC for chain \(chainId)")
    }

    /// 删除自定义 RPC（对应扩展的 removeCustomRPC）
    /// - Parameter chainId: 链 ID
    func removeCustomRPC(chainId: Int) {
        customRPCs.removeValue(forKey: chainId)
        rpcStatusCache.removeValue(forKey: chainId)

        saveCustomRPCs()
        saveStatusCache()

        print("[RPCManager] ✅ Removed custom RPC for chain \(chainId)")
    }

    /// 检查是否有启用的自定义 RPC（对应扩展的 hasCustomRPC）
    /// - Parameter chainId: 链 ID
    /// - Returns: 是否有启用的自定义 RPC
    func hasCustomRPC(chainId: Int) -> Bool {
        guard let rpcItem = customRPCs[chainId] else { return false }
        return rpcItem.enable
    }

    /// 获取生效的 RPC URL（如果有启用的自定义 RPC，返回自定义；否则返回 nil）
    /// - Parameter chainId: 链 ID
    /// - Returns: 生效的自定义 RPC URL，如果没有则返回 nil
    func getEffectiveRPC(chainId: Int) -> String? {
        guard let rpcItem = customRPCs[chainId], rpcItem.enable else {
            return nil
        }
        return rpcItem.url
    }

    /// 获取所有自定义 RPC
    /// - Returns: 所有自定义 RPC 字典
    func getAllCustomRPCs() -> [Int: RPCItem] {
        return customRPCs
    }

    /// 获取指定链的自定义 RPC
    /// - Parameter chainId: 链 ID
    /// - Returns: RPC 配置项，如果没有则返回 nil
    func getRPC(chainId: Int) -> RPCItem? {
        return customRPCs[chainId]
    }

    // MARK: - Public Methods - RPC Testing

    /// 测试 RPC 连接（对应扩展的 ping）
    /// - Parameter chainId: 链 ID
    /// - Returns: RPC 是否可用
    func ping(chainId: Int) async -> Bool {
        // 1. 检查缓存是否有效
        if let cachedStatus = rpcStatusCache[chainId], !cachedStatus.isExpired {
            print("[RPCManager] 📦 Using cached RPC status for chain \(chainId): \(cachedStatus.available)")
            return cachedStatus.available
        }

        // 2. 获取自定义 RPC URL
        guard let rpcItem = customRPCs[chainId] else {
            print("[RPCManager] ⚠️ No custom RPC found for chain \(chainId)")
            return false
        }

        guard let rpcURL = URL(string: rpcItem.url) else {
            print("[RPCManager] ❌ Invalid RPC URL for chain \(chainId): \(rpcItem.url)")
            return false
        }

        // 3. 测试 RPC（调用 eth_blockNumber）
        let available: Bool
        do {
            let _ = try await sendRPCRequest(
                method: "eth_blockNumber",
                params: [],
                rpcURL: rpcURL,
                timeout: 2000  // 2 秒超时
            )
            available = true
            print("[RPCManager] ✅ RPC ping successful for chain \(chainId)")
        } catch {
            available = false
            print("[RPCManager] ❌ RPC ping failed for chain \(chainId): \(error.localizedDescription)")
        }

        // 4. 缓存结果（60 秒）
        let now = Date().timeIntervalSince1970
        let expireAt = now + statusCacheDuration
        rpcStatusCache[chainId] = RPCStatus(
            expireAt: expireAt,
            available: available,
            lastPingAt: now
        )
        saveStatusCache()

        return available
    }

    /// 内部方法：发送 RPC 请求（避免依赖 NetworkManager）
    private func sendRPCRequest(
        method: String,
        params: [Any],
        rpcURL: URL,
        timeout: TimeInterval
    ) async throws -> String {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout / 1000.0  // 转换毫秒为秒

        let rpcRequest: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 1...999999),
            "method": method,
            "params": params
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: rpcRequest)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw RPCError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let error = json?["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            throw RPCError.rpcError(message)
        }

        guard let result = json?["result"] as? String else {
            throw RPCError.emptyResponse
        }

        return result
    }

    enum RPCError: Error {
        case invalidResponse
        case emptyResponse
        case rpcError(String)
    }

    /// 批量测试多个 RPC 连接
    /// - Parameter chainIds: 链 ID 数组
    /// - Returns: 链 ID -> 是否可用的字典
    func batchPing(chainIds: [Int]) async -> [Int: Bool] {
        var results: [Int: Bool] = [:]

        await withTaskGroup(of: (Int, Bool).self) { group in
            for chainId in chainIds {
                group.addTask {
                    let available = await self.ping(chainId: chainId)
                    return (chainId, available)
                }
            }

            for await (chainId, available) in group {
                results[chainId] = available
            }
        }

        return results
    }

    /// 清除 RPC 状态缓存
    /// - Parameter chainId: 链 ID，如果为 nil 则清除所有缓存
    func clearStatusCache(chainId: Int? = nil) {
        if let chainId = chainId {
            rpcStatusCache.removeValue(forKey: chainId)
            print("[RPCManager] ✅ Cleared status cache for chain \(chainId)")
        } else {
            rpcStatusCache.removeAll()
            print("[RPCManager] ✅ Cleared all status cache")
        }
        saveStatusCache()
    }

    /// 获取 RPC 状态（用于 UI 显示）
    /// - Parameter chainId: 链 ID
    /// - Returns: RPC 状态，如果没有缓存则返回 nil
    func getRPCStatus(chainId: Int) -> RPCStatus? {
        guard let status = rpcStatusCache[chainId], !status.isExpired else {
            return nil
        }
        return status
    }

    // MARK: - Private Methods - Storage

    private func loadCustomRPCs() {
        if let data = storageManager.getData(forKey: customRPCKey),
           let decoded = try? JSONDecoder().decode([Int: RPCItem].self, from: data) {
            customRPCs = decoded
            print("[RPCManager] 📦 Loaded \(customRPCs.count) custom RPCs")
        }
    }

    private func saveCustomRPCs() {
        if let encoded = try? JSONEncoder().encode(customRPCs) {
            storageManager.setData(encoded, forKey: customRPCKey)
        }
    }

    private func loadStatusCache() {
        if let data = storageManager.getData(forKey: statusCacheKey),
           let decoded = try? JSONDecoder().decode([Int: RPCStatus].self, from: data) {
            // 过滤掉已过期的缓存
            rpcStatusCache = decoded.filter { !$0.value.isExpired }
            print("[RPCManager] 📦 Loaded \(rpcStatusCache.count) RPC status cache entries")
        }
    }

    private func saveStatusCache() {
        // 只保存未过期的缓存
        let validCache = rpcStatusCache.filter { !$0.value.isExpired }
        if let encoded = try? JSONEncoder().encode(validCache) {
            storageManager.setData(encoded, forKey: statusCacheKey)
        }
    }

    // MARK: - Public Methods - Utility

    /// 验证 RPC URL 格式
    /// - Parameter url: RPC URL
    /// - Returns: URL 是否有效
    func isValidRPCURL(_ url: String) -> Bool {
        guard let url = URL(string: url) else { return false }
        guard let scheme = url.scheme else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// 获取统计信息（用于调试）
    func getStatistics() -> RPCStatistics {
        let totalCustomRPCs = customRPCs.count
        let enabledCustomRPCs = customRPCs.values.filter { $0.enable }.count
        let cachedStatuses = rpcStatusCache.count
        let availableRPCs = rpcStatusCache.values.filter { $0.available && !$0.isExpired }.count

        return RPCStatistics(
            totalCustomRPCs: totalCustomRPCs,
            enabledCustomRPCs: enabledCustomRPCs,
            cachedStatuses: cachedStatuses,
            availableRPCs: availableRPCs
        )
    }
}

// MARK: - Supporting Types

struct RPCStatistics {
    let totalCustomRPCs: Int
    let enabledCustomRPCs: Int
    let cachedStatuses: Int
    let availableRPCs: Int

    var description: String {
        """
        RPCManager Statistics:
        - Total Custom RPCs: \(totalCustomRPCs)
        - Enabled Custom RPCs: \(enabledCustomRPCs)
        - Cached Statuses: \(cachedStatuses)
        - Available RPCs: \(availableRPCs)
        """
    }
}
