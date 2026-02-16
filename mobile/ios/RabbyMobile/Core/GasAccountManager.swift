import Foundation
import Combine
import BigInt

/// Gas Account Manager - Gasless transaction support with sponsored gas
/// Equivalent to Web version's gasAccount service
@MainActor
class GasAccountManager: ObservableObject {
    static let shared = GasAccountManager()
    
    @Published var accountId: String?
    @Published var signature: String?
    @Published var isLoggedIn = false
    @Published var gasBalance: [GasBalance] = []
    
    /// Computed total balance across all chains
    var balance: Double {
        gasBalance.reduce(0) { $0 + $1.amount }
    }
    
    /// Alias for isLoggedIn
    var isActivated: Bool { isLoggedIn }
    
    /// Transaction history placeholder
    struct GasTransaction: Identifiable {
        let id: String
        let type: String  // "deposit" or "usage"
        let amount: Double
        let date: Date
    }
    @Published var transactions: [GasTransaction] = []
    
    private let storage = StorageManager.shared
    private let openAPIService = OpenAPIService.shared
    private let gasAccountKey = "rabby_gas_account"
    
    // MARK: - Models
    
    struct GasBalance: Codable, Identifiable {
        let id: String
        let chainId: String
        let tokenId: String
        let amount: Double
        let symbol: String
        let logo: String?
    }
    
    struct GasAccountData: Codable {
        var accountId: String?
        var signature: String?
        var account: AccountInfo?
        var hasClaimedGift: Bool
        
        struct AccountInfo: Codable {
            let address: String
            let type: String
            let brandName: String
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadAccount()
    }
    
    // MARK: - Public Methods
    
    /// Login to gas account
    func login(address: String, signature: String) async throws {
        // Verify signature with backend
        do {
            _ = try await openAPIService.gasAccountLogin(address: address, signature: signature)
            
            self.accountId = address
            self.signature = signature
            self.isLoggedIn = true
            
            saveAccount(address: address, signature: signature)
            
            // Load gas balance
            try await loadGasBalance()
        } catch {
            print("❌ Failed to login to gas account: \(error)")
            throw GasAccountError.loginFailed
        }
    }
    
    /// Logout from gas account
    func logout() {
        accountId = nil
        signature = nil
        isLoggedIn = false
        gasBalance = []
        
        let data = GasAccountData(
            accountId: nil,
            signature: nil,
            account: nil,
            hasClaimedGift: false
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            storage.setData(encoded, forKey: gasAccountKey)
        }
    }
    
    /// Load gas balance
    func loadGasBalance() async throws {
        guard let accountId = accountId, let signature = signature else {
            throw GasAccountError.notLoggedIn
        }

        do {
            let response = try await openAPIService.getGasAccountBalance(
                address: accountId,
                signature: signature
            )
            
            self.gasBalance = response.data.map { item in
                GasBalance(
                    id: "\(item.chain_id)_\(item.token_id)",
                    chainId: item.chain_id,
                    tokenId: item.token_id,
                    amount: item.amount,
                    symbol: item.symbol,
                    logo: item.logo
                )
            }
        } catch {
            print("❌ Failed to load gas balance: \(error)")
            throw error
        }
    }
    
    /// Check if can use gas account for transaction
    func canUseGasAccount(chain: Chain, estimatedGas: String) async -> Bool {
        guard isLoggedIn else { return false }
        
        // Check if have enough gas balance for this chain
        if let balance = gasBalance.first(where: { $0.chainId == chain.serverId }) {
            // Convert estimated gas to double and compare
            if let gasAmount = Double(estimatedGas), balance.amount >= gasAmount {
                return true
            }
        }
        
        return false
    }
    
    /// Build gasless transaction
    func buildGaslessTransaction(
        transaction: EthereumTransaction,
        fromAddress: String,
        chain: Chain
    ) async throws -> EthereumTransaction {
        guard let accountId = accountId, let signature = signature else {
            throw GasAccountError.notLoggedIn
        }

        let valueHex = "0x" + String(transaction.value, radix: 16)
        let dataHex = "0x" + transaction.data.hexString

        do {
            let response = try await openAPIService.buildGasAccountTx(
                address: accountId,
                signature: signature,
                chainId: chain.serverId,
                from: fromAddress,
                to: transaction.to,
                value: valueHex,
                data: dataHex
            )
            
            // Return modified transaction with sponsor info
            var gaslessTransaction = transaction
            gaslessTransaction.gasLimit = BigUInt(response.gas_limit) ?? BigUInt(300000)
            gaslessTransaction.maxFeePerGas = BigUInt(0) // Sponsored
            gaslessTransaction.maxPriorityFeePerGas = BigUInt(0) // Sponsored
            
            return gaslessTransaction
        } catch {
            print("❌ Failed to build gasless transaction: \(error)")
            throw GasAccountError.buildTransactionFailed
        }
    }
    
    /// Claim free gas gift (for new users)
    func claimGift() async throws {
        guard let accountId = accountId, let signature = signature else {
            throw GasAccountError.notLoggedIn
        }

        do {
            _ = try await openAPIService.claimGasAccountGift(
                address: accountId,
                signature: signature
            )
            
            // Mark as claimed
            markGiftAsClaimed()
            
            // Reload balance
            try await loadGasBalance()
        } catch {
            print("❌ Failed to claim gas gift: \(error)")
            throw GasAccountError.claimGiftFailed
        }
    }
    
    /// Check if gift has been claimed
    func hasClaimedGift() -> Bool {
        if let data = storage.getData(forKey: gasAccountKey),
           let accountData = try? JSONDecoder().decode(GasAccountData.self, from: data) {
            return accountData.hasClaimedGift
        }
        return false
    }
    
    // MARK: - Private Methods
    
    /// Deposit to gas account (placeholder)
    func deposit(amount: Double) async {
        print("GasAccountManager: deposit \(amount)")
        try? await loadGasBalance()
    }
    
    private func loadAccount() {
        if let data = storage.getData(forKey: gasAccountKey),
           let accountData = try? JSONDecoder().decode(GasAccountData.self, from: data) {
            self.accountId = accountData.accountId
            self.signature = accountData.signature
            self.isLoggedIn = accountData.accountId != nil
            
            if isLoggedIn {
                Task {
                    try? await loadGasBalance()
                }
            }
        }
    }
    
    private func saveAccount(address: String, signature: String) {
        let data = GasAccountData(
            accountId: address,
            signature: signature,
            account: GasAccountData.AccountInfo(
                address: address,
                type: "eoa",
                brandName: "Rabby"
            ),
            hasClaimedGift: false
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            storage.setData(encoded, forKey: gasAccountKey)
        }
    }
    
    private func markGiftAsClaimed() {
        if let data = storage.getData(forKey: gasAccountKey),
           var accountData = try? JSONDecoder().decode(GasAccountData.self, from: data) {
            accountData.hasClaimedGift = true
            
            if let encoded = try? JSONEncoder().encode(accountData) {
                storage.setData(encoded, forKey: gasAccountKey)
            }
        }
    }
}

// MARK: - Errors

enum GasAccountError: Error, LocalizedError {
    case notLoggedIn
    case loginFailed
    case buildTransactionFailed
    case insufficientGasBalance
    case claimGiftFailed
    
    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Not logged in to gas account"
        case .loginFailed:
            return "Failed to login to gas account"
        case .buildTransactionFailed:
            return "Failed to build gasless transaction"
        case .insufficientGasBalance:
            return "Insufficient gas balance"
        case .claimGiftFailed:
            return "Failed to claim gas gift"
        }
    }
}
