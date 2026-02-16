import Foundation
import Combine
import BigInt

/// Security Engine Manager - Transaction risk analysis and security checks
/// Equivalent to Web version's securityEngine service (385 lines)
@MainActor
class SecurityEngineManager: ObservableObject {
    static let shared = SecurityEngineManager()
    
    @Published var rules: [SecurityRule] = []
    @Published var userData: UserSecurityData = UserSecurityData()
    
    private let storage = StorageManager.shared
    private let openAPIService = OpenAPIService.shared
    private let securityKey = "rabby_security_engine"

    private let cache = WalletSecurityCache()
    
    // MARK: - Models
    
    struct SecurityRule: Codable, Identifiable {
        let id: String
        let name: String
        let description: String
        var enable: Bool
        let level: RiskLevel
        var customThreshold: [String: Any]?
        
        enum CodingKeys: String, CodingKey {
            case id, name, description, enable, level
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decode(String.self, forKey: .name)
            description = try c.decode(String.self, forKey: .description)
            enable = try c.decode(Bool.self, forKey: .enable)
            level = try c.decode(RiskLevel.self, forKey: .level)
        }
        
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(description, forKey: .description)
            try c.encode(enable, forKey: .enable)
            try c.encode(level, forKey: .level)
        }
        
        init(id: String, name: String, description: String, enable: Bool, level: RiskLevel) {
            self.id = id; self.name = name; self.description = description
            self.enable = enable; self.level = level
        }
    }
    
    enum RiskLevel: String, Codable {
        case safe = "safe"
        case warning = "warning"
        case danger = "danger"
        case forbidden = "forbidden"
    }
    
    struct UserSecurityData: Codable {
        var originBlacklist: [String] = []
        var originWhitelist: [String] = []
        var contractBlacklist: [ContractAddress] = []
        var contractWhitelist: [ContractAddress] = []
        var addressBlacklist: [String] = []
        var addressWhitelist: [String] = []
    }
    
    struct ContractAddress: Codable, Equatable {
        let address: String
        let chainId: String
    }
    
    struct SecurityCheckResult {
        let ruleId: String
        let level: RiskLevel
        let message: String
        let enable: Bool
    }

    /// In-memory cache to avoid repeated `/v1/wallet/*` checks when the same approval re-renders.
    actor WalletSecurityCache {
        struct Entry<T> {
            let value: T
            let expiresAt: Date
        }

        private var checkTxCache: [String: Entry<OpenAPIService.WalletSecurityCheckResponse>] = [:]
        private var preExecCache: [String: Entry<OpenAPIService.WalletExplainTxResponse>] = [:]
        private var checkTextCache: [String: Entry<OpenAPIService.WalletSecurityCheckResponse>] = [:]
        private var checkOriginCache: [String: Entry<OpenAPIService.WalletSecurityCheckResponse>] = [:]

        func getCheckTx(key: String) -> OpenAPIService.WalletSecurityCheckResponse? {
            if let e = checkTxCache[key], e.expiresAt > Date() { return e.value }
            checkTxCache[key] = nil
            return nil
        }

        func setCheckTx(key: String, value: OpenAPIService.WalletSecurityCheckResponse, ttl: TimeInterval) {
            checkTxCache[key] = Entry(value: value, expiresAt: Date().addingTimeInterval(ttl))
        }

        func getPreExec(key: String) -> OpenAPIService.WalletExplainTxResponse? {
            if let e = preExecCache[key], e.expiresAt > Date() { return e.value }
            preExecCache[key] = nil
            return nil
        }

        func setPreExec(key: String, value: OpenAPIService.WalletExplainTxResponse, ttl: TimeInterval) {
            preExecCache[key] = Entry(value: value, expiresAt: Date().addingTimeInterval(ttl))
        }

        func getCheckText(key: String) -> OpenAPIService.WalletSecurityCheckResponse? {
            if let e = checkTextCache[key], e.expiresAt > Date() { return e.value }
            checkTextCache[key] = nil
            return nil
        }

        func setCheckText(key: String, value: OpenAPIService.WalletSecurityCheckResponse, ttl: TimeInterval) {
            checkTextCache[key] = Entry(value: value, expiresAt: Date().addingTimeInterval(ttl))
        }

        func getCheckOrigin(key: String) -> OpenAPIService.WalletSecurityCheckResponse? {
            if let e = checkOriginCache[key], e.expiresAt > Date() { return e.value }
            checkOriginCache[key] = nil
            return nil
        }

        func setCheckOrigin(key: String, value: OpenAPIService.WalletSecurityCheckResponse, ttl: TimeInterval) {
            checkOriginCache[key] = Entry(value: value, expiresAt: Date().addingTimeInterval(ttl))
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadRules()
        loadUserData()
    }
    
    // MARK: - Security Check
    
    /// Execute security check on transaction
    func checkTransaction(
        from: String,
        to: String,
        value: String,
        data: String,
        chain: Chain,
        origin: String? = nil,
        nonce: String? = nil,
        gas: String? = nil,
        gasLimit: String? = nil,
        gasPrice: String? = nil,
        maxFeePerGas: String? = nil,
        maxPriorityFeePerGas: String? = nil
    ) async -> [SecurityCheckResult] {
        var results: [SecurityCheckResult] = []
        
        // 0) Local allow/deny lists (always enforced)
        if userData.addressBlacklist.contains(where: { $0.lowercased() == to.lowercased() }) {
            results.append(SecurityCheckResult(
                ruleId: "address_blacklist",
                level: .forbidden,
                message: "Recipient address is in your blacklist",
                enable: true
            ))
        }

        if userData.contractBlacklist.contains(where: {
            $0.address.lowercased() == to.lowercased() && $0.chainId == chain.serverId
        }) {
            results.append(SecurityCheckResult(
                ruleId: "contract_blacklist",
                level: .forbidden,
                message: "Contract is in your blacklist",
                enable: true
            ))
        }

        // 1) Extension-compatible server-side security checks (best effort)
        let normalizedOrigin = normalizeOrigin(origin)
        let tx = OpenAPIService.WalletTx(
            chainId: chain.id,
            data: data.isEmpty ? "0x" : data,
            from: from,
            gas: gas,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasPrice: gasPrice,
            nonce: nonce?.isEmpty == false ? nonce! : "0x0",
            to: to,
            value: value.isEmpty ? "0x0" : value
        )

        // Cache key: chain + from + to + value + data + origin (nonce/gas are optional and often missing)
        let checkTxKey = "checkTx|\(chain.id)|\(from.lowercased())|\(to.lowercased())|\(value)|\(data)|\(normalizedOrigin)"
        if let cached = await cache.getCheckTx(key: checkTxKey) {
            results.append(contentsOf: mapWalletSecurityResponse(cached))
        } else if !normalizedOrigin.isEmpty {
            do {
                let resp = try await openAPIService.walletCheckTx(
                    tx: tx,
                    origin: normalizedOrigin,
                    address: from,
                    updateNonce: nonce == nil || nonce?.isEmpty == true
                )
                await cache.setCheckTx(key: checkTxKey, value: resp, ttl: 20)
                results.append(contentsOf: mapWalletSecurityResponse(resp))
            } catch {
                // Non-blocking: fall back to local heuristics below.
            }
        }

        // 2) Local heuristics fallback (also useful when API is rate-limited)
        let isNewAddress = !ContactBookManager.shared.hasContact(address: to)
            && !WhitelistManager.shared.isWhitelisted(to)
            && !userData.addressWhitelist.contains(where: { $0.lowercased() == to.lowercased() })
        if isNewAddress {
            results.append(SecurityCheckResult(
                ruleId: "new_address",
                level: .warning,
                message: "You have never interacted with this address",
                enable: true
            ))
        }

        if let eth = tryParseNativeValueETH(valueHex: value), eth >= 1.0 {
            results.append(SecurityCheckResult(
                ruleId: "high_value",
                level: .warning,
                message: "High value transfer detected (\(String(format: "%.4f", eth)) \(chain.nativeTokenSymbol))",
                enable: true
            ))
        }

        if data != "0x" && data.count > 2 {
            do {
                let isVerified = try await checkContractVerified(address: to, chain: chain)
                if !isVerified {
                    results.append(SecurityCheckResult(
                        ruleId: "unverified_contract",
                        level: .warning,
                        message: "Interacting with an unverified contract",
                        enable: true
                    ))
                }
            } catch { }
        }

        // 3) Apply rule enable flags for locally-defined rules only.
        return results.filter { result in
            guard let rule = rules.first(where: { $0.id == result.ruleId }) else { return true }
            return rule.enable
        }
    }
    
    /// Check message signing security
    func checkSignMessage(from: String, message: String, origin: String?) async -> [SecurityCheckResult] {
        var results: [SecurityCheckResult] = []

        let normalizedOrigin = normalizeOrigin(origin)
        if !normalizedOrigin.isEmpty,
           userData.originBlacklist.contains(normalizedOrigin.lowercased()) {
            results.append(SecurityCheckResult(
                ruleId: "origin_blacklist",
                level: .forbidden,
                message: "This DApp origin is in your blacklist",
                enable: true
            ))
        }

        if !normalizedOrigin.isEmpty {
            let key = "checkText|\(from.lowercased())|\(normalizedOrigin)|\(message)"
            if let cached = await cache.getCheckText(key: key) {
                results.append(contentsOf: mapWalletSecurityResponse(cached))
            } else {
                do {
                    let resp = try await openAPIService.walletCheckText(
                        address: from,
                        origin: normalizedOrigin,
                        text: message
                    )
                    await cache.setCheckText(key: key, value: resp, ttl: 20)
                    results.append(contentsOf: mapWalletSecurityResponse(resp))
                } catch {
                    // Best effort only.
                }
            }
        }

        return results.filter { result in
            guard let rule = rules.first(where: { $0.id == result.ruleId }) else { return true }
            return rule.enable
        }
    }

    /// Pre-execute simulation used for accurate balance change and risk preview.
    func preExecTransaction(
        from: String,
        to: String,
        value: String,
        data: String,
        chain: Chain,
        origin: String? = nil,
        nonce: String? = nil,
        gas: String? = nil,
        gasLimit: String? = nil,
        gasPrice: String? = nil,
        maxFeePerGas: String? = nil,
        maxPriorityFeePerGas: String? = nil
    ) async -> OpenAPIService.WalletExplainTxResponse? {
        let normalizedOrigin = normalizeOrigin(origin)
        guard !normalizedOrigin.isEmpty else { return nil }

        let tx = OpenAPIService.WalletTx(
            chainId: chain.id,
            data: data.isEmpty ? "0x" : data,
            from: from,
            gas: gas,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasPrice: gasPrice,
            nonce: nonce?.isEmpty == false ? nonce! : "0x0",
            to: to,
            value: value.isEmpty ? "0x0" : value
        )
        let key = "preExec|\(chain.id)|\(from.lowercased())|\(to.lowercased())|\(value)|\(data)|\(normalizedOrigin)"
        if let cached = await cache.getPreExec(key: key) { return cached }

        do {
            let resp = try await openAPIService.walletPreExecTx(
                tx: tx,
                origin: normalizedOrigin,
                address: from,
                updateNonce: nonce == nil || nonce?.isEmpty == true
            )
            await cache.setPreExec(key: key, value: resp, ttl: 20)
            return resp
        } catch {
            return nil
        }
    }

    /// Extension-compatible origin checks for DApp connection prompts (best effort).
    func checkOrigin(address: String, origin: String) async -> OpenAPIService.WalletSecurityCheckResponse? {
        let normalizedOrigin = normalizeOrigin(origin)
        guard !normalizedOrigin.isEmpty else { return nil }
        let key = "checkOrigin|\(address.lowercased())|\(normalizedOrigin)"
        if let cached = await cache.getCheckOrigin(key: key) { return cached }
        do {
            let resp = try await openAPIService.walletCheckOrigin(address: address, origin: normalizedOrigin)
            await cache.setCheckOrigin(key: key, value: resp, ttl: 60)
            return resp
        } catch {
            return nil
        }
    }
    
    // MARK: - Blacklist/Whitelist Management
    
    func addOriginToWhitelist(_ origin: String) {
        let lower = origin.lowercased()
        guard !userData.originWhitelist.contains(lower) else { return }
        userData.originWhitelist.append(lower)
        saveUserData()
    }
    
    func removeOriginFromWhitelist(_ origin: String) {
        userData.originWhitelist.removeAll { $0.lowercased() == origin.lowercased() }
        saveUserData()
    }
    
    func addOriginToBlacklist(_ origin: String) {
        let lower = origin.lowercased()
        guard !userData.originBlacklist.contains(lower) else { return }
        userData.originBlacklist.append(lower)
        saveUserData()
    }
    
    func addContractToBlacklist(_ contract: ContractAddress) {
        guard !userData.contractBlacklist.contains(contract) else { return }
        userData.contractBlacklist.append(ContractAddress(
            address: contract.address.lowercased(), chainId: contract.chainId
        ))
        saveUserData()
    }
    
    func addContractToWhitelist(_ contract: ContractAddress) {
        guard !userData.contractWhitelist.contains(contract) else { return }
        userData.contractWhitelist.append(ContractAddress(
            address: contract.address.lowercased(), chainId: contract.chainId
        ))
        saveUserData()
    }
    
    func removeContractFromWhitelist(_ contract: ContractAddress) {
        userData.contractWhitelist.removeAll {
            $0.address.lowercased() == contract.address.lowercased() && $0.chainId == contract.chainId
        }
        saveUserData()
    }
    
    func addAddressToBlacklist(_ address: String) {
        let lower = address.lowercased()
        guard !userData.addressBlacklist.contains(lower) else { return }
        userData.addressBlacklist.append(lower)
        saveUserData()
    }
    
    func removeAddressFromBlacklist(_ address: String) {
        userData.addressBlacklist.removeAll { $0.lowercased() == address.lowercased() }
        saveUserData()
    }
    
    // MARK: - Rule Management
    
    func setRuleEnabled(ruleId: String, enabled: Bool) {
        if let index = rules.firstIndex(where: { $0.id == ruleId }) {
            rules[index].enable = enabled
            saveRules()
        }
    }
    
    // MARK: - Private Methods
    
    private func checkContractVerified(address: String, chain: Chain) async throws -> Bool {
        let response = try await openAPIService.checkContract(
            address: address,
            chainId: chain.serverId
        )
        return response.is_verified ?? false
    }

    private func mapWalletSecurityResponse(_ resp: OpenAPIService.WalletSecurityCheckResponse) -> [SecurityCheckResult] {
        func mapItem(_ item: OpenAPIService.WalletSecurityCheckItem) -> SecurityCheckResult {
            let msg: String
            if !item.alert.isEmpty {
                msg = item.alert
            } else if !item.description.isEmpty {
                msg = item.description
            } else {
                msg = "Security check triggered (#\(item.id))"
            }

            return SecurityCheckResult(
                ruleId: "wallet_rule_\(item.id)",
                level: mapDecision(item.decision),
                message: msg,
                enable: true
            )
        }

        // Keep ordering: forbidden -> danger -> warning.
        var results: [SecurityCheckResult] = []
        results.append(contentsOf: resp.forbidden_list.map(mapItem))
        results.append(contentsOf: resp.danger_list.map(mapItem))
        results.append(contentsOf: resp.warning_list.map(mapItem))
        return results
    }

    private func mapDecision(_ decision: OpenAPIService.WalletSecurityDecision) -> RiskLevel {
        switch decision {
        case .forbidden: return .forbidden
        case .danger: return .danger
        case .warning: return .warning
        case .pass, .loading, .pending: return .safe
        }
    }

    private func normalizeOrigin(_ origin: String?) -> String {
        guard var s = origin?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return "" }
        // When we receive a full URL, normalize to origin (scheme+host+port) to match extension behavior.
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") {
            s = "https://\(s)"
        }
        guard let components = URLComponents(string: s),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased() else {
            return s.lowercased()
        }
        var originStr = "\(scheme)://\(host)"
        if let port = components.port {
            let isDefaultPort = (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
            if !isDefaultPort { originStr += ":\(port)" }
        }
        return originStr
    }

    private func tryParseNativeValueETH(valueHex: String) -> Double? {
        let trimmed = valueHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("0x") else { return nil }
        let hexBody = trimmed.dropFirst(2)
        if hexBody.isEmpty { return 0 }
        // BigInt is available in the project; use BigUInt for correctness.
        if let big = BigUInt(String(hexBody), radix: 16) {
            // NOTE: for native token it's always 18 decimals in EVM chains.
            let denom = pow(10.0, 18.0)
            return Double(big) / denom
        }
        return nil
    }
    
    private func loadRules() {
        if let data = storage.getData(forKey: securityKey + "_rules"),
           let r = try? JSONDecoder().decode([SecurityRule].self, from: data) {
            self.rules = r
        } else {
            self.rules = defaultRules()
        }
    }
    
    private func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            storage.setData(data, forKey: securityKey + "_rules")
        }
    }
    
    private func loadUserData() {
        if let data = storage.getData(forKey: securityKey + "_userdata"),
           let ud = try? JSONDecoder().decode(UserSecurityData.self, from: data) {
            self.userData = ud
        }
    }
    
    private func saveUserData() {
        if let data = try? JSONEncoder().encode(userData) {
            storage.setData(data, forKey: securityKey + "_userdata")
        }
    }
    
    private func defaultRules() -> [SecurityRule] {
        return [
            SecurityRule(id: "address_blacklist", name: "Blacklisted Address", description: "Block transactions to blacklisted addresses", enable: true, level: .forbidden),
            SecurityRule(id: "contract_blacklist", name: "Blacklisted Contract", description: "Block interactions with blacklisted contracts", enable: true, level: .forbidden),
            SecurityRule(id: "origin_blacklist", name: "Blacklisted Origin", description: "Block requests from blacklisted DApp origins", enable: true, level: .forbidden),
            SecurityRule(id: "new_address", name: "New Address Warning", description: "Warn when sending to a never-interacted address", enable: true, level: .warning),
            SecurityRule(id: "high_value", name: "High Value Transaction", description: "Warn on high value transactions", enable: true, level: .warning),
            SecurityRule(id: "unverified_contract", name: "Unverified Contract", description: "Warn when interacting with unverified contracts", enable: true, level: .warning),
        ]
    }
}
