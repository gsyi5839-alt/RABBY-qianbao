import Foundation
import Combine

/// Whitelist Manager - Manage trusted addresses for transactions
/// Equivalent to Web version's whitelist.ts
@MainActor
class WhitelistManager: ObservableObject {
    static let shared = WhitelistManager()
    
    @Published var whitelistedAddresses: [String] = []
    @Published var isEnabled: Bool = true
    
    private let storage = StorageManager.shared
    private let whitelistKey = "rabby_whitelist"
    private let enabledKey = "rabby_whitelist_enabled"
    
    // MARK: - Initialization
    
    private init() {
        loadWhitelist()
    }
    
    // MARK: - Public Methods
    
    /// Get all whitelisted addresses
    func getWhitelist() -> [String] {
        return whitelistedAddresses
    }
    
    /// Check if address is in whitelist
    func isWhitelisted(_ address: String) -> Bool {
        return whitelistedAddresses.contains { $0.lowercased() == address.lowercased() }
    }
    
    /// Add address to whitelist
    func addToWhitelist(_ address: String) throws {
        // Validate address
        guard EthereumUtil.isValidAddress(address) else {
            throw WhitelistError.invalidAddress
        }
        
        let lowercasedAddress = address.lowercased()
        
        // Check if already exists
        guard !isWhitelisted(lowercasedAddress) else {
            return // Already whitelisted
        }
        
        whitelistedAddresses.append(lowercasedAddress)
        saveWhitelist()
    }
    
    /// Remove address from whitelist
    func removeFromWhitelist(_ address: String) {
        whitelistedAddresses.removeAll { $0.lowercased() == address.lowercased() }
        saveWhitelist()
    }
    
    /// Set entire whitelist
    func setWhitelist(_ addresses: [String]) {
        whitelistedAddresses = addresses.map { $0.lowercased() }
        saveWhitelist()
    }
    
    /// Clear all whitelisted addresses
    func clearWhitelist() {
        whitelistedAddresses.removeAll()
        saveWhitelist()
    }
    
    /// Enable whitelist feature
    func enableWhitelist() {
        isEnabled = true
        saveEnabled()
    }
    
    /// Disable whitelist feature
    func disableWhitelist() {
        isEnabled = false
        saveEnabled()
    }
    
    /// Check if whitelist is enabled
    func isWhitelistEnabled() -> Bool {
        // Always return true per Web version logic
        return true
    }
    
    /// Batch add addresses to whitelist
    func addMultipleToWhitelist(_ addresses: [String]) throws {
        for address in addresses {
            try addToWhitelist(address)
        }
    }
    
    /// Get whitelist count
    func getWhitelistCount() -> Int {
        return whitelistedAddresses.count
    }
    
    // MARK: - Private Methods
    
    private func loadWhitelist() {
        // Load addresses
        if let data = storage.getData(forKey: whitelistKey),
           let addresses = try? JSONDecoder().decode([String].self, from: data) {
            whitelistedAddresses = addresses
        }
        
        // Load enabled state
        isEnabled = storage.getBool(forKey: enabledKey) ?? true
    }
    
    private func saveWhitelist() {
        if let data = try? JSONEncoder().encode(whitelistedAddresses) {
            storage.setData(data, forKey: whitelistKey)
        }
    }
    
    private func saveEnabled() {
        storage.setBool(isEnabled, forKey: enabledKey)
    }
}

// MARK: - Errors

enum WhitelistError: Error, LocalizedError {
    case invalidAddress
    case addressNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid Ethereum address"
        case .addressNotFound:
            return "Address not found in whitelist"
        }
    }
}
