import Foundation
import Combine
import BigInt

/// Transaction manager for building, signing, and sending transactions
@MainActor
class TransactionManager: ObservableObject {
    static let shared = TransactionManager()
    
    @Published var pendingTransactions: [TransactionGroup] = []
    @Published var completedTransactions: [TransactionGroup] = []
    
    /// Number of pending transactions
    var pendingCount: Int {
        pendingTransactions.count
    }
    
    private let networkManager = NetworkManager.shared
    private let storageManager = StorageManager.shared
    private let keyringManager = KeyringManager.shared
    private let chainManager = ChainManager.shared
    
    private var transactionWatchers: [String: Timer] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadTransactions()
        startTransactionWatcher()
    }
    
    // MARK: - Transaction Building
    
    /// Build a transaction with recommended gas and nonce
    func buildTransaction(
        from: String,
        to: String,
        value: String,
        data: String = "0x",
        chain: Chain
    ) async throws -> EthereumTransaction {
        // Get recommended nonce
        let nonce = try await getRecommendedNonce(address: from, chain: chain)
        
        // Estimate gas
        let gasEstimate = try await estimateGas(
            from: from,
            to: to,
            value: value,
            data: data,
            chain: chain
        )
        
        // Get gas price
        let gasPrice = try await getGasPrice(chain: chain)
        
        var transaction = EthereumTransaction(
            to: to,
            from: from,
            nonce: nonce,
            value: BigUInt(value.hexToData() ?? Data()) ?? 0,
            data: data.hexToData() ?? Data(),
            gasLimit: gasEstimate,
            chainId: chain.id
        )
        
        // Check if chain supports EIP-1559
        if chain.supportsEIP1559 {
            let feeData = try await getEIP1559FeeData(chain: chain)
            transaction.maxFeePerGas = feeData.maxFeePerGas
            transaction.maxPriorityFeePerGas = feeData.maxPriorityFeePerGas
        } else {
            transaction.gasPrice = gasPrice
        }
        
        return transaction
    }
    
    /// Build ERC20 transfer transaction
    func buildERC20Transfer(
        from: String,
        to: String,
        tokenAddress: String,
        amount: String,
        chain: Chain
    ) async throws -> EthereumTransaction {
        // Encode transfer function call
        // transfer(address,uint256)
        let functionSignature = "0xa9059cbb"
        let toAddressPadded = to.replacingOccurrences(of: "0x", with: "").padLeft(toLength: 64, withPad: "0")
        let amountPadded = amount.replacingOccurrences(of: "0x", with: "").padLeft(toLength: 64, withPad: "0")
        let data = functionSignature + toAddressPadded + amountPadded
        
        return try await buildTransaction(
            from: from,
            to: tokenAddress,
            value: "0x0",
            data: data,
            chain: chain
        )
    }
    
    /// Build token approval transaction
    func buildTokenApproval(
        from: String,
        tokenAddress: String,
        spender: String,
        amount: String,
        chain: Chain
    ) async throws -> EthereumTransaction {
        // Encode approve function call
        // approve(address,uint256)
        let functionSignature = "0x095ea7b3"
        let spenderPadded = spender.replacingOccurrences(of: "0x", with: "").padLeft(toLength: 64, withPad: "0")
        let amountPadded = amount.replacingOccurrences(of: "0x", with: "").padLeft(toLength: 64, withPad: "0")
        let data = functionSignature + spenderPadded + amountPadded
        
        return try await buildTransaction(
            from: from,
            to: tokenAddress,
            value: "0x0",
            data: data,
            chain: chain
        )
    }
    
    // MARK: - Gas Estimation
    
    func estimateGas(
        from: String,
        to: String,
        value: String,
        data: String,
        chain: Chain
    ) async throws -> BigUInt {
        let transaction: [String: Any] = [
            "from": from,
            "to": to,
            "value": value,
            "data": data
        ]
        
        let gasHex = try await networkManager.estimateGas(transaction: transaction, chain: chain)
        let gasEstimate = BigUInt(gasHex.hexToData() ?? Data()) ?? BigUInt(21000)
        
        // Add 20% buffer for safety
        let gasWithBuffer = gasEstimate * 12 / 10
        return gasWithBuffer
    }
    
    func getGasPrice(chain: Chain) async throws -> BigUInt {
        let gasPriceHex = try await networkManager.getGasPrice(chain: chain)
        return BigUInt(gasPriceHex.hexToData() ?? Data()) ?? 0
    }
    
    func getEIP1559FeeData(chain: Chain) async throws -> EIP1559FeeData {
        // Get base fee from latest block
        let blockNumber = try await networkManager.getBlockNumber(chain: chain)
        let block = try await networkManager.getBlockByNumber(blockNumber: blockNumber, fullTransactions: false, chain: chain)
        
        // Parse base fee (in hex)
        let baseFee = BigUInt(block.hash.hexToData() ?? Data()) ?? 0
        
        // Calculate maxPriorityFeePerGas (tip)
        let priorityFee = baseFee / 10 // 10% of base fee as default tip
        
        // Calculate maxFeePerGas (base fee * 2 + priority fee for next block buffer)
        let maxFeePerGas = baseFee * 2 + priorityFee
        
        return EIP1559FeeData(
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: priorityFee
        )
    }
    
    // MARK: - Nonce Management
    
    func getRecommendedNonce(address: String, chain: Chain) async throws -> BigUInt {
        // Get on-chain nonce
        let onChainNonceHex = try await networkManager.getTransactionCount(address: address, chain: chain)
        let onChainNonce = BigUInt(onChainNonceHex.hexToData() ?? Data()) ?? 0
        
        // Get local pending nonce
        let localNonce = getLocalPendingNonce(address: address, chainId: chain.id)
        
        // Return max of both
        return max(onChainNonce, localNonce)
    }
    
    private func getLocalPendingNonce(address: String, chainId: Int) -> BigUInt {
        let pendingTxs = pendingTransactions.filter { group in
            group.chainId == chainId &&
            group.txs.contains(where: { $0.rawTx.from.lowercased() == address.lowercased() })
        }
        
        if let maxNonce = pendingTxs.map({ BigUInt($0.nonce) }).max() {
            return maxNonce + 1
        }
        
        return 0
    }
    
    // MARK: - Transaction Sending
    
    /// Sign and send transaction
    func sendTransaction(_ transaction: EthereumTransaction) async throws -> String {
        guard let chain = chainManager.getChain(byId: transaction.chainId) else {
            throw TransactionError.invalidChain
        }
        
        // Sign transaction
        let signedTxData = try await keyringManager.signTransaction(
            address: transaction.from,
            transaction: transaction
        )
        
        let signedTxHex = "0x" + signedTxData.hexString
        
        // Send raw transaction
        let txHash = try await networkManager.sendRawTransaction(
            signedTransaction: signedTxHex,
            chain: chain
        )
        
        // Add to pending transactions
        await addPendingTransaction(transaction: transaction, hash: txHash, chain: chain)
        
        // Start watching transaction
        watchTransaction(hash: txHash, chain: chain)
        
        return txHash
    }
    
    /// Broadcast a signed transaction
    func broadcastTransaction(_ signedTxData: Data) async throws -> String {
        guard let chain = chainManager.selectedChain else {
            throw TransactionError.invalidChain
        }
        let signedTxHex = "0x" + signedTxData.hexString
        let txHash = try await networkManager.sendRawTransaction(
            signedTransaction: signedTxHex,
            chain: chain
        )
        return txHash
    }
    
    /// Speed up transaction (replace with higher gas)
    func speedUpTransaction(originalTx: TransactionHistoryItem) async throws -> String {
        let originalTxData = originalTx.rawTx
        
        guard let chain = chainManager.getChain(byId: originalTxData.chainId) else {
            throw TransactionError.invalidChain
        }
        
        var newTx = originalTxData
        
        // Increase gas price by 10%
        if let gasPrice = newTx.gasPrice {
            newTx.gasPrice = gasPrice * 11 / 10
        }
        if let maxFeePerGas = newTx.maxFeePerGas {
            newTx.maxFeePerGas = maxFeePerGas * 11 / 10
        }
        if let maxPriorityFeePerGas = newTx.maxPriorityFeePerGas {
            newTx.maxPriorityFeePerGas = maxPriorityFeePerGas * 11 / 10
        }
        
        return try await sendTransaction(newTx)
    }
    
    /// Cancel transaction (send 0 ETH to self with same nonce)
    func cancelTransaction(originalTx: TransactionHistoryItem) async throws -> String {
        let originalTxData = originalTx.rawTx
        
        guard let chain = chainManager.getChain(byId: originalTxData.chainId) else {
            throw TransactionError.invalidChain
        }
        
        var cancelTx = EthereumTransaction(
            to: originalTxData.from, // Send to self
            from: originalTxData.from,
            nonce: originalTxData.nonce,
            value: 0, // 0 ETH
            data: Data(),
            gasLimit: 21000,
            chainId: originalTxData.chainId
        )
        
        // Use higher gas price than original
        if let gasPrice = originalTxData.gasPrice {
            cancelTx.gasPrice = gasPrice * 12 / 10
        }
        
        return try await sendTransaction(cancelTx)
    }
    
    // MARK: - Transaction History
    
    private func addPendingTransaction(transaction: EthereumTransaction, hash: String, chain: Chain) async {
        let historyItem = TransactionHistoryItem(
            rawTx: transaction,
            createdAt: Date().timeIntervalSince1970,
            isCompleted: false,
            hash: hash,
            failed: false
        )
        
        let group = TransactionGroup(
            chainId: transaction.chainId,
            nonce: Int(transaction.nonce),
            txs: [historyItem],
            isPending: true,
            createdAt: Date().timeIntervalSince1970,
            isFailed: false
        )
        
        pendingTransactions.append(group)
        saveTransactions()
    }
    
    private func updateTransactionStatus(hash: String, receipt: TransactionReceipt) {
        // Find and update transaction
        for (index, group) in pendingTransactions.enumerated() {
            if let txIndex = group.txs.firstIndex(where: { $0.hash == hash }) {
                var updatedGroup = group
                var updatedTx = group.txs[txIndex]
                
                updatedTx.isCompleted = true
                updatedTx.completedAt = Date().timeIntervalSince1970
                updatedTx.failed = !receipt.isSuccess
                updatedTx.gasUsed = Int(receipt.gasUsed.hexToData()?.hexString ?? "0", radix: 16)
                
                updatedGroup.txs[txIndex] = updatedTx
                updatedGroup.isPending = false
                updatedGroup.completedAt = Date().timeIntervalSince1970
                updatedGroup.isFailed = !receipt.isSuccess
                
                pendingTransactions.remove(at: index)
                completedTransactions.insert(updatedGroup, at: 0)
                
                saveTransactions()
                break
            }
        }
    }
    
    // MARK: - Transaction Watching
    
    private func startTransactionWatcher() {
        // Check pending transactions every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkPendingTransactions()
            }
        }
    }
    
    private func watchTransaction(hash: String, chain: Chain) {
        let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                do {
                    if let receipt = try await self?.networkManager.getTransactionReceipt(hash: hash, chain: chain) {
                        self?.updateTransactionStatus(hash: hash, receipt: receipt)
                        timer.invalidate()
                        self?.transactionWatchers.removeValue(forKey: hash)
                    }
                } catch {
                    print("Error watching transaction \(hash): \(error)")
                }
            }
        }
        
        transactionWatchers[hash] = timer
    }
    
    private func checkPendingTransactions() async {
        for group in pendingTransactions {
            guard let chain = chainManager.getChain(byId: group.chainId) else {
                continue
            }
            
            for tx in group.txs {
                guard let hash = tx.hash else { continue }
                
                do {
                    if let receipt = try await networkManager.getTransactionReceipt(hash: hash, chain: chain) {
                        updateTransactionStatus(hash: hash, receipt: receipt)
                    }
                } catch {
                    print("Error checking transaction \(hash): \(error)")
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadTransactions() {
        if let pending = try? storageManager.getPreference(forKey: "pendingTransactions", type: [TransactionGroup].self) {
            pendingTransactions = pending
        }
        
        if let completed = try? storageManager.getPreference(forKey: "completedTransactions", type: [TransactionGroup].self) {
            completedTransactions = completed.prefix(100).map { $0 } // Keep last 100
        }
    }
    
    private func saveTransactions() {
        try? storageManager.savePreference(pendingTransactions, forKey: "pendingTransactions")
        try? storageManager.savePreference(completedTransactions, forKey: "completedTransactions")
    }
    
    // MARK: - Query Methods
    
    func getTransactionHistory(address: String) -> (pendings: [TransactionGroup], completeds: [TransactionGroup]) {
        let pendings = pendingTransactions.filter { group in
            group.txs.contains(where: { $0.rawTx.from.lowercased() == address.lowercased() })
        }
        
        let completeds = completedTransactions.filter { group in
            group.txs.contains(where: { $0.rawTx.from.lowercased() == address.lowercased() })
        }
        
        return (pendings, completeds)
    }
    
    func getTransactionByHash(_ hash: String) -> TransactionHistoryItem? {
        for group in pendingTransactions + completedTransactions {
            if let tx = group.txs.first(where: { $0.hash == hash }) {
                return tx
            }
        }
        return nil
    }
    
    func clearHistory() {
        completedTransactions.removeAll()
        saveTransactions()
    }
}

// MARK: - Supporting Types

struct TransactionHistoryItem: Codable {
    var rawTx: EthereumTransaction
    let createdAt: TimeInterval
    var isCompleted: Bool
    var completedAt: TimeInterval?
    var hash: String?
    var failed: Bool
    var gasUsed: Int?
    var isSubmitFailed: Bool?
    
    enum CodingKeys: String, CodingKey {
        case rawTx, createdAt, isCompleted, completedAt, hash, failed, gasUsed, isSubmitFailed
    }
}

struct TransactionGroup: Codable, Identifiable {
    let id = UUID()
    let chainId: Int
    let nonce: Int
    var txs: [TransactionHistoryItem]
    var isPending: Bool
    let createdAt: TimeInterval
    var completedAt: TimeInterval?
    var isFailed: Bool
    var isSubmitFailed: Bool?
    
    enum CodingKeys: String, CodingKey {
        case chainId, nonce, txs, isPending, createdAt, completedAt, isFailed, isSubmitFailed
    }
}

struct EIP1559FeeData {
    let maxFeePerGas: BigUInt
    let maxPriorityFeePerGas: BigUInt
}

// MARK: - Chain Extension

extension Chain {
    var supportsEIP1559: Bool {
        // EIP-1559 support for major chains
        switch id {
        case 1, 5, 11155111: // Ethereum Mainnet, Goerli, Sepolia
            return true
        case 10, 420: // Optimism
            return true
        case 137, 80001: // Polygon
            return true
        case 42161, 421613: // Arbitrum
            return true
        case 8453: // Base
            return true
        default:
            return false
        }
    }
}

// MARK: - Errors

enum TransactionError: Error, LocalizedError {
    case invalidChain
    case invalidTransaction
    case insufficientBalance
    case gasEstimateFailed
    case nonceError
    case signingFailed
    case sendFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidChain:
            return "Invalid chain configuration"
        case .invalidTransaction:
            return "Invalid transaction data"
        case .insufficientBalance:
            return "Insufficient balance for transaction"
        case .gasEstimateFailed:
            return "Failed to estimate gas"
        case .nonceError:
            return "Nonce error"
        case .signingFailed:
            return "Failed to sign transaction"
        case .sendFailed:
            return "Failed to send transaction"
        }
    }
}

// MARK: - EthereumTransaction Extension

extension EthereumTransaction: Codable {
    enum CodingKeys: String, CodingKey {
        case to, from, nonce, value, data, gasLimit, chainId
        case maxFeePerGas, maxPriorityFeePerGas, gasPrice
        case v, r, s
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        to = try container.decodeIfPresent(String.self, forKey: .to)
        from = try container.decode(String.self, forKey: .from)
        
        let nonceString = try container.decode(String.self, forKey: .nonce)
        nonce = BigUInt(nonceString.hexToData() ?? Data()) ?? 0
        
        let valueString = try container.decode(String.self, forKey: .value)
        value = BigUInt(valueString.hexToData() ?? Data()) ?? 0
        
        let dataString = try container.decode(String.self, forKey: .data)
        data = dataString.hexToData() ?? Data()
        
        let gasLimitString = try container.decode(String.self, forKey: .gasLimit)
        gasLimit = BigUInt(gasLimitString.hexToData() ?? Data()) ?? 0
        
        chainId = try container.decode(Int.self, forKey: .chainId)
        
        if let maxFeeString = try container.decodeIfPresent(String.self, forKey: .maxFeePerGas) {
            maxFeePerGas = BigUInt(maxFeeString.hexToData() ?? Data())
        }
        
        if let maxPriorityString = try container.decodeIfPresent(String.self, forKey: .maxPriorityFeePerGas) {
            maxPriorityFeePerGas = BigUInt(maxPriorityString.hexToData() ?? Data())
        }
        
        if let gasPriceString = try container.decodeIfPresent(String.self, forKey: .gasPrice) {
            gasPrice = BigUInt(gasPriceString.hexToData() ?? Data())
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(to, forKey: .to)
        try container.encode(from, forKey: .from)
        try container.encode("0x" + String(nonce, radix: 16), forKey: .nonce)
        try container.encode("0x" + String(value, radix: 16), forKey: .value)
        try container.encode("0x" + data.hexString, forKey: .data)
        try container.encode("0x" + String(gasLimit, radix: 16), forKey: .gasLimit)
        try container.encode(chainId, forKey: .chainId)
        
        if let maxFee = maxFeePerGas {
            try container.encode("0x" + String(maxFee, radix: 16), forKey: .maxFeePerGas)
        }
        
        if let maxPriority = maxPriorityFeePerGas {
            try container.encode("0x" + String(maxPriority, radix: 16), forKey: .maxPriorityFeePerGas)
        }
        
        if let price = gasPrice {
            try container.encode("0x" + String(price, radix: 16), forKey: .gasPrice)
        }
    }
}
