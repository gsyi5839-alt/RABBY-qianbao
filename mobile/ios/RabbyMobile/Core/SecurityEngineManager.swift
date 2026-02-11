import Foundation
import Combine

/// Security Engine Manager - Transaction risk analysis and security checks
/// Equivalent to Web version's securityEngine service (385 lines)
@MainActor
class SecurityEngineManager: ObservableObject {
    static let shared = SecurityEngineManager()
    
    @Published var rules: [SecurityRule] = []
    @Published var userData: UserSecurityData = UserSecurityData()
    
    private let storage = StorageManager.shared
    private let securityKey = "rabby_security_engine"
    
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
    
    // MARK: - Initialization
    
    private init() {
        loadRules()
        loadUserData()
    }
    
    // MARK: - Security Check
    
    /// Execute security check on transaction
    func checkTransaction(
        from: String, to: String, value: String, data: String, chain: Chain
    ) async -> [SecurityCheckResult] {
        var results: [SecurityCheckResult] = []
        
        // Rule 1: Check if recipient is in blacklist
        if userData.addressBlacklist.contains(where: { $0.lowercased() == to.lowercased() }) {
            results.append(SecurityCheckResult(
                ruleId: "address_blacklist", level: .forbidden,
                message: "Recipient address is in your blacklist", enable: true
            ))
        }
        
        // Rule 2: Check if contract is in blacklist
        if userData.contractBlacklist.contains(where: {
            $0.address.lowercased() == to.lowercased() && $0.chainId == chain.serverId
        }) {
            results.append(SecurityCheckResult(
                ruleId: "contract_blacklist", level: .forbidden,
                message: "Contract is in your blacklist", enable: true
            ))
        }
        
        // Rule 3: Check if sending to new address (never interacted before)
        let isNewAddress = !ContactBookManager.shared.hasContact(address: to)
            && !WhitelistManager.shared.isWhitelisted(to)
        if isNewAddress {
            results.append(SecurityCheckResult(
                ruleId: "new_address", level: .warning,
                message: "You have never interacted with this address", enable: true
            ))
        }
        
        // Rule 4: Check high value transaction
        if let valueDouble = Double(value), valueDouble > 1.0 {
            results.append(SecurityCheckResult(
                ruleId: "high_value", level: .warning,
                message: "High value transaction detected", enable: true
            ))
        }
        
        // Rule 5: Check if contract is verified (via API)
        if data != "0x" && data.count > 2 {
            do {
                let isVerified = try await checkContractVerified(address: to, chain: chain)
                if !isVerified {
                    results.append(SecurityCheckResult(
                        ruleId: "unverified_contract", level: .warning,
                        message: "Interacting with an unverified contract", enable: true
                    ))
                }
            } catch { /* Skip if check fails */ }
        }
        
        return results.filter { result in
            guard let rule = rules.first(where: { $0.id == result.ruleId }) else { return true }
            return rule.enable
        }
    }
    
    /// Check message signing security
    func checkSignMessage(from: String, message: String, origin: String?) -> [SecurityCheckResult] {
        var results: [SecurityCheckResult] = []
        
        if let origin = origin, userData.originBlacklist.contains(origin.lowercased()) {
            results.append(SecurityCheckResult(
                ruleId: "origin_blacklist", level: .forbidden,
                message: "This DApp origin is in your blacklist", enable: true
            ))
        }
        
        return results
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
        struct ContractCheckResponse: Codable {
            let is_verified: Bool?
        }
        let url = "https://api.rabby.io/v1/contract/check"
        let params: [String: Any] = ["address": address, "chain_id": chain.serverId]
        let response: ContractCheckResponse = try await NetworkManager.shared.get(url: url, parameters: params)
        return response.is_verified ?? false
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
