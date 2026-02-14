import Foundation
import Combine
import BigInt

/// Bridge Manager - Cross-chain Bridge Aggregator
/// Equivalent to Web version's bridge service
/// Implements complete bridge execution pipeline:
/// checkAllowance -> approveForBridge -> buildBridgeTx -> signAndSendBridge -> watchBridgeStatus
@MainActor
class BridgeManager: ObservableObject {
    static let shared = BridgeManager()

    @Published var selectedFromChain: String?
    @Published var selectedToChain: String?
    @Published var selectedFromToken: SwapManager.Token?
    @Published var selectedToToken: SwapManager.Token?
    @Published var selectedAggregators: [String] = []
    @Published var quotes: [BridgeQuote] = []
    @Published var isLoading = false

    /// Current execution step for UI progress tracking
    @Published var executionStep: BridgeExecutionStep = .idle

    /// Active bridge watch tasks keyed by source txHash
    @Published var activeBridges: [String: BridgeWatchState] = [:]

    private let networkManager = NetworkManager.shared
    private let storage = StorageManager.shared
    private let transactionManager = TransactionManager.shared
    private let keyringManager = KeyringManager.shared

    private let bridgeKey = "rabby_bridge_settings"

    /// MaxUint256 for unlimited approval
    private static let maxUint256Hex = String(repeating: "f", count: 64)

    // MARK: - Models

    struct BridgeQuote: Identifiable {
        let id: String
        let aggregatorId: String
        let aggregatorName: String
        let aggregatorLogo: String?
        let bridgeId: String
        let fromChainId: String
        let toChainId: String
        let fromToken: SwapManager.Token
        let toToken: SwapManager.Token
        let fromAmount: String
        let toAmount: String
        let estimatedTime: String // e.g., "3-5 minutes"
        let gasFee: String
        let bridgeFee: String
        let rabbyFee: Double
        let data: String
        let to: String
        let needApprove: Bool
        let spender: String?
    }

    struct BridgeSettings: Codable {
        var selectedFromChain: String?
        var selectedToChain: String?
        var selectedAggregators: [String]
    }

    /// Tracks the execution step of the bridge pipeline for UI progress display
    enum BridgeExecutionStep: Equatable {
        case idle
        case checkingAllowance
        case approving
        case waitingApprovalConfirmation
        case buildingTransaction
        case signing
        case sending
        case watchingBridgeStatus
        case completed(txHash: String)
        case failed(message: String)

        var displayText: String {
            switch self {
            case .idle: return ""
            case .checkingAllowance: return "Checking allowance..."
            case .approving: return "Approving token..."
            case .waitingApprovalConfirmation: return "Waiting for approval confirmation..."
            case .buildingTransaction: return "Building bridge transaction..."
            case .signing: return "Signing transaction..."
            case .sending: return "Sending transaction..."
            case .watchingBridgeStatus: return "Bridge in progress..."
            case .completed: return "Bridge completed!"
            case .failed(let msg): return "Failed: \(msg)"
            }
        }

        var isInProgress: Bool {
            switch self {
            case .idle, .completed, .failed: return false
            default: return true
            }
        }
    }

    /// Status of a bridge being watched
    struct BridgeWatchState {
        let fromTxHash: String
        let aggregatorId: String
        let bridgeId: String
        let fromChainId: String
        let toChainId: String
        let fromTokenSymbol: String
        let toTokenSymbol: String
        let fromAmount: String
        let toAmount: String
        var status: BridgeWatchStatus
        var toTxHash: String?
        var startedAt: Date
        var updatedAt: Date
    }

    enum BridgeWatchStatus: String {
        case pending
        case bridging
        case completed
        case failed

        var displayText: String {
            switch self {
            case .pending: return "Pending"
            case .bridging: return "Bridging..."
            case .completed: return "Completed"
            case .failed: return "Failed"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    // MARK: - Public Methods

    /// Get bridge quotes from aggregators
    func getQuotes(
        fromToken: SwapManager.Token,
        toToken: SwapManager.Token,
        amount: String,
        fromChain: Chain,
        toChain: Chain,
        userAddress: String
    ) async throws -> [BridgeQuote] {
        isLoading = true
        defer { isLoading = false }

        // Call Rabby API to get bridge quotes
        let url = "https://api.rabby.io/v1/bridge/quote"
        let params: [String: Any] = [
            "from_chain_id": fromChain.serverId,
            "to_chain_id": toChain.serverId,
            "from_token_id": fromToken.id,
            "to_token_id": toToken.id,
            "amount": amount,
            "user_address": userAddress,
        ]

        do {
            let response: BridgeQuoteResponse = try await networkManager.get(url: url, parameters: params)

            // Filter by selected aggregators if any
            var filteredData = response.data
            if !selectedAggregators.isEmpty {
                filteredData = filteredData.filter { selectedAggregators.contains($0.aggregator_id) }
            }

            // Convert to BridgeQuote models
            let quotes = filteredData.map { quoteData -> BridgeQuote in
                BridgeQuote(
                    id: "\(quoteData.aggregator_id)_\(quoteData.bridge_id)",
                    aggregatorId: quoteData.aggregator_id,
                    aggregatorName: quoteData.aggregator_name,
                    aggregatorLogo: quoteData.aggregator_logo,
                    bridgeId: quoteData.bridge_id,
                    fromChainId: fromChain.serverId,
                    toChainId: toChain.serverId,
                    fromToken: fromToken,
                    toToken: toToken,
                    fromAmount: amount,
                    toAmount: quoteData.to_token_amount,
                    estimatedTime: quoteData.estimated_time,
                    gasFee: quoteData.gas_fee,
                    bridgeFee: quoteData.bridge_fee,
                    rabbyFee: quoteData.rabby_fee,
                    data: quoteData.data,
                    to: quoteData.to,
                    needApprove: quoteData.need_approve,
                    spender: quoteData.spender
                )
            }

            self.quotes = quotes
            return quotes
        } catch {
            print("[BridgeManager] Failed to get bridge quotes: \(error)")
            throw error
        }
    }

    // MARK: - 1. Check Allowance

    /// Check ERC20 token allowance for the bridge contract spender.
    /// Returns the current allowance as BigUInt.
    /// For native tokens (ETH, etc.) this always returns MaxUint256 (no approval needed).
    func checkAllowance(
        tokenAddress: String,
        ownerAddress: String,
        spenderAddress: String,
        chain: Chain
    ) async throws -> BigUInt {
        // Native token never needs approval
        let isNativeToken = tokenAddress.lowercased() == chain.nativeTokenAddress.lowercased()
            || tokenAddress.lowercased() == "0x0000000000000000000000000000000000000000"
            || tokenAddress.lowercased() == "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

        if isNativeToken {
            // Return max value -> no approval needed
            return BigUInt(2).power(256) - 1
        }

        // ERC20 allowance(address owner, address spender)
        // Function selector: 0xdd62ed3e
        let ownerPadded = ownerAddress.replacingOccurrences(of: "0x", with: "").padLeft(toLength: 64, withPad: "0")
        let spenderPadded = spenderAddress.replacingOccurrences(of: "0x", with: "").padLeft(toLength: 64, withPad: "0")
        let callData = "0xdd62ed3e" + ownerPadded + spenderPadded

        let callTx: [String: Any] = [
            "to": tokenAddress,
            "data": callData
        ]

        let resultHex = try await networkManager.call(transaction: callTx, chain: chain)
        let allowance = TransactionManager.parseBigUIntFromHex(resultHex)

        return allowance
    }

    // MARK: - 2. Approve For Bridge

    /// Send ERC20 approve transaction for the bridge contract.
    /// Approves MaxUint256 so user does not need to re-approve for subsequent bridges.
    /// Waits for the approval transaction to be confirmed on-chain before returning.
    ///
    /// - Returns: The approval transaction hash
    func approveForBridge(
        tokenAddress: String,
        spenderAddress: String,
        fromAddress: String,
        chain: Chain
    ) async throws -> String {
        executionStep = .approving

        // Build approval tx via TransactionManager (handles nonce, gas, EIP-1559)
        let approveTx = try await transactionManager.buildTokenApproval(
            from: fromAddress,
            tokenAddress: tokenAddress,
            spender: spenderAddress,
            amount: Self.maxUint256Hex,
            chain: chain
        )

        // Sign and send via TransactionManager (which also adds to pending + watches)
        let txHash = try await transactionManager.sendTransaction(approveTx)

        print("[BridgeManager] Approval tx sent: \(txHash)")

        // Wait for approval confirmation
        executionStep = .waitingApprovalConfirmation
        try await waitForTransactionConfirmation(txHash: txHash, chain: chain)

        print("[BridgeManager] Approval tx confirmed: \(txHash)")
        return txHash
    }

    // MARK: - 3. Build Bridge Transaction

    /// Build the bridge transaction by calling the OpenAPI /v1/bridge/build_tx endpoint.
    /// Returns a fully-built EthereumTransaction with nonce, gas, and fee parameters.
    func buildBridgeTx(
        quote: BridgeQuote,
        fromAddress: String,
        fromChain: Chain
    ) async throws -> EthereumTransaction {
        executionStep = .buildingTransaction

        // Call Rabby API to get the actual bridge transaction data
        let url = "https://api.rabby.io/v1/bridge/build_tx"
        let params: [String: Any] = [
            "aggregator_id": quote.aggregatorId,
            "bridge_id": quote.bridgeId,
            "from_chain_id": quote.fromChainId,
            "to_chain_id": quote.toChainId,
            "from_token_id": quote.fromToken.id,
            "to_token_id": quote.toToken.id,
            "amount": quote.fromAmount,
            "user_address": fromAddress,
        ]

        let buildResponse: BridgeBuildTxResponse
        do {
            buildResponse = try await networkManager.get(url: url, parameters: params)
        } catch {
            // If build_tx endpoint fails, fall back to quote data
            print("[BridgeManager] build_tx API failed, using quote data: \(error)")
            return try await buildBridgeTxFromQuoteData(quote: quote, fromAddress: fromAddress, fromChain: fromChain)
        }

        // Parse the response into transaction parameters
        let toAddress = buildResponse.to ?? quote.to
        let txDataHex = buildResponse.data ?? quote.data
        let txData = txDataHex.hexToData() ?? Data()

        // Determine value: use API response or calculate from quote
        let valueHex: String
        if let apiValue = buildResponse.value, !apiValue.isEmpty {
            valueHex = apiValue
        } else {
            // For native token sends, value = fromAmount; for ERC20, value = 0
            let isNative = quote.fromToken.address.lowercased() == fromChain.nativeTokenAddress.lowercased()
                || quote.fromToken.address.lowercased() == "0x0000000000000000000000000000000000000000"
                || quote.fromToken.address.lowercased() == "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
            valueHex = isNative ? quote.fromAmount : "0x0"
        }

        // Use TransactionManager.buildTransaction to get proper nonce, gas, fees
        let transaction = try await transactionManager.buildTransaction(
            from: fromAddress,
            to: toAddress,
            value: valueHex,
            data: "0x" + txData.hexString,
            chain: fromChain
        )

        // Override gas limit if the API provided one
        if let apiGasLimit = buildResponse.gas_limit {
            var tx = transaction
            let parsedGas = TransactionManager.parseBigUIntFromHex(apiGasLimit)
            if parsedGas > 0 {
                // Add 20% buffer
                tx.gasLimit = parsedGas * 12 / 10
            }
            return tx
        }

        return transaction
    }

    /// Fallback: build bridge transaction directly from quote data
    private func buildBridgeTxFromQuoteData(
        quote: BridgeQuote,
        fromAddress: String,
        fromChain: Chain
    ) async throws -> EthereumTransaction {
        let isNative = quote.fromToken.address.lowercased() == fromChain.nativeTokenAddress.lowercased()
            || quote.fromToken.address.lowercased() == "0x0000000000000000000000000000000000000000"
            || quote.fromToken.address.lowercased() == "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
        let valueHex = isNative ? quote.fromAmount : "0x0"

        let txData = quote.data.hexToData() ?? Data()

        return try await transactionManager.buildTransaction(
            from: fromAddress,
            to: quote.to,
            value: valueHex,
            data: "0x" + txData.hexString,
            chain: fromChain
        )
    }

    // MARK: - 4. Sign and Send Bridge

    /// Sign the bridge transaction via KeyringManager and send it via NetworkManager.
    /// Records the transaction in TransactionManager's history.
    ///
    /// - Returns: The bridge transaction hash
    func signAndSendBridge(
        transaction: EthereumTransaction,
        fromAddress: String,
        fromChain: Chain
    ) async throws -> String {
        // Sign
        executionStep = .signing
        // TransactionManager.sendTransaction handles sign + send + history in one call

        executionStep = .sending
        let txHash = try await transactionManager.sendTransaction(transaction)

        print("[BridgeManager] Bridge tx sent: \(txHash)")
        return txHash
    }

    // MARK: - 5. Watch Bridge Status

    /// Start watching the cross-chain bridge status.
    /// Polls /v1/bridge/status periodically until the bridge is completed or failed.
    /// Updates the activeBridges dictionary and executionStep for UI updates.
    func watchBridgeStatus(
        txHash: String,
        quote: BridgeQuote,
        fromChain: Chain
    ) async {
        executionStep = .watchingBridgeStatus

        // Register the bridge watch state
        let watchState = BridgeWatchState(
            fromTxHash: txHash,
            aggregatorId: quote.aggregatorId,
            bridgeId: quote.bridgeId,
            fromChainId: quote.fromChainId,
            toChainId: quote.toChainId,
            fromTokenSymbol: quote.fromToken.symbol,
            toTokenSymbol: quote.toToken.symbol,
            fromAmount: quote.fromAmount,
            toAmount: quote.toAmount,
            status: .pending,
            toTxHash: nil,
            startedAt: Date(),
            updatedAt: Date()
        )
        activeBridges[txHash] = watchState

        // Poll every 10 seconds, up to 60 minutes max
        let maxAttempts = 360 // 60 min at 10s intervals
        let pollInterval: UInt64 = 10_000_000_000 // 10 seconds in nanoseconds

        for attempt in 0..<maxAttempts {
            do {
                try await Task.sleep(nanoseconds: pollInterval)

                let status = try await getBridgeStatus(txHash: txHash, fromChain: fromChain)

                // Update the watch state
                var updatedState = activeBridges[txHash] ?? watchState
                updatedState.updatedAt = Date()
                updatedState.toTxHash = status.toTxHash

                switch status.status.lowercased() {
                case "success", "completed", "done":
                    updatedState.status = .completed
                    activeBridges[txHash] = updatedState
                    executionStep = .completed(txHash: txHash)
                    print("[BridgeManager] Bridge completed: \(txHash) -> \(status.toTxHash ?? "?")")
                    return

                case "failed", "error", "refunded":
                    updatedState.status = .failed
                    activeBridges[txHash] = updatedState
                    executionStep = .failed(message: "Bridge transaction failed")
                    print("[BridgeManager] Bridge failed: \(txHash)")
                    return

                case "bridging", "in_progress":
                    updatedState.status = .bridging
                    activeBridges[txHash] = updatedState

                default:
                    // Still pending
                    updatedState.status = .pending
                    activeBridges[txHash] = updatedState
                }

            } catch {
                // API errors during polling are not fatal; keep polling
                print("[BridgeManager] Status poll attempt \(attempt + 1) failed: \(error)")
                // After 5 consecutive errors, reduce polling to avoid hammering
                if attempt > 5 {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // extra 5s
                }
            }
        }

        // Timed out after max attempts
        print("[BridgeManager] Bridge status watch timed out for: \(txHash)")
        if var state = activeBridges[txHash] {
            state.status = .pending // still unknown
            state.updatedAt = Date()
            activeBridges[txHash] = state
        }
    }

    // MARK: - Complete Bridge Execution Pipeline

    /// Execute the full bridge pipeline:
    /// 1. Check allowance (if ERC20)
    /// 2. Approve if needed (and wait for confirmation)
    /// 3. Build bridge transaction (via API)
    /// 4. Sign and send bridge transaction
    /// 5. Start watching bridge status
    ///
    /// - Returns: The bridge source chain transaction hash
    func executeBridge(
        quote: BridgeQuote,
        fromAddress: String,
        fromChain: Chain
    ) async throws -> String {
        executionStep = .idle

        do {
            // Step 1: Check allowance (for ERC20 tokens only)
            executionStep = .checkingAllowance

            let isNativeToken = quote.fromToken.address.lowercased() == fromChain.nativeTokenAddress.lowercased()
                || quote.fromToken.address.lowercased() == "0x0000000000000000000000000000000000000000"
                || quote.fromToken.address.lowercased() == "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

            if !isNativeToken, quote.needApprove, let spender = quote.spender {
                // Parse the required amount
                let requiredAmount = TransactionManager.parseBigUIntFromHex(
                    quote.fromAmount.hasPrefix("0x") ? quote.fromAmount : "0x" + quote.fromAmount
                )

                // Check current allowance
                let currentAllowance = try await checkAllowance(
                    tokenAddress: quote.fromToken.address,
                    ownerAddress: fromAddress,
                    spenderAddress: spender,
                    chain: fromChain
                )

                print("[BridgeManager] Allowance check: current=\(currentAllowance), required=\(requiredAmount)")

                // Step 2: Approve if insufficient
                if currentAllowance < requiredAmount {
                    let approveTxHash = try await approveForBridge(
                        tokenAddress: quote.fromToken.address,
                        spenderAddress: spender,
                        fromAddress: fromAddress,
                        chain: fromChain
                    )
                    print("[BridgeManager] Approval completed: \(approveTxHash)")
                } else {
                    print("[BridgeManager] Sufficient allowance, skipping approval")
                }
            } else {
                print("[BridgeManager] Native token or no approval needed, skipping allowance check")
            }

            // Step 3: Build bridge transaction
            let transaction = try await buildBridgeTx(
                quote: quote,
                fromAddress: fromAddress,
                fromChain: fromChain
            )

            // Step 4: Sign and send
            let txHash = try await signAndSendBridge(
                transaction: transaction,
                fromAddress: fromAddress,
                fromChain: fromChain
            )

            // Post bridge analytics
            await postBridge(fromChain: fromChain, txHash: txHash, quote: quote)

            // Step 5: Start watching bridge status in background
            executionStep = .completed(txHash: txHash)

            Task {
                await watchBridgeStatus(
                    txHash: txHash,
                    quote: quote,
                    fromChain: fromChain
                )
            }

            return txHash

        } catch {
            executionStep = .failed(message: error.localizedDescription)
            throw error
        }
    }

    /// Check and confirm bridge transaction (called from TransactionBroadcastWatcher)
    func checkAndConfirmBridge(txHash: String, chainId: Int) {
        // Track bridge confirmation for analytics
        print("[BridgeManager] Bridge confirmed - txHash: \(txHash), chainId: \(chainId)")
    }

    /// Set selected aggregators
    func setSelectedAggregators(_ aggregators: [String]) {
        self.selectedAggregators = aggregators
        saveSettings()
    }

    /// Reset execution state (e.g., when user dismisses error)
    func resetExecutionState() {
        executionStep = .idle
    }

    /// Get bridge status from API
    func getBridgeStatus(txHash: String, fromChain: Chain) async throws -> BridgeStatus {
        let url = "https://api.rabby.io/v1/bridge/status"
        let params: [String: Any] = [
            "tx_id": txHash,
            "chain_id": fromChain.serverId,
        ]

        let response: BridgeStatusResponse = try await networkManager.get(url: url, parameters: params)

        return BridgeStatus(
            status: response.status,
            fromTxHash: txHash,
            toTxHash: response.to_tx_hash,
            estimatedTime: response.estimated_time,
            actualTime: response.actual_time
        )
    }

    // MARK: - Private Methods

    /// Wait for a transaction to be confirmed on-chain.
    /// Polls getTransactionReceipt every 3 seconds up to ~5 minutes.
    private func waitForTransactionConfirmation(txHash: String, chain: Chain, timeoutSeconds: Int = 300) async throws {
        let maxAttempts = timeoutSeconds / 3

        for attempt in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

            do {
                if let receipt = try await networkManager.getTransactionReceipt(hash: txHash, chain: chain) {
                    if receipt.isSuccess {
                        return // Confirmed successfully
                    } else {
                        throw BridgeError.approvalFailed(txHash: txHash)
                    }
                }
            } catch let error as BridgeError {
                throw error // Re-throw bridge-specific errors
            } catch {
                // Receipt not yet available or RPC error; keep polling
                print("[BridgeManager] Waiting for tx \(txHash), attempt \(attempt + 1): \(error.localizedDescription)")
            }
        }

        throw BridgeError.approvalTimeout
    }

    private func loadSettings() {
        if let data = storage.getData(forKey: bridgeKey),
           let settings = try? JSONDecoder().decode(BridgeSettings.self, from: data) {
            self.selectedFromChain = settings.selectedFromChain
            self.selectedToChain = settings.selectedToChain
            self.selectedAggregators = settings.selectedAggregators
        }
    }

    private func saveSettings() {
        let settings = BridgeSettings(
            selectedFromChain: selectedFromChain,
            selectedToChain: selectedToChain,
            selectedAggregators: selectedAggregators
        )
        if let data = try? JSONEncoder().encode(settings) {
            storage.setData(data, forKey: bridgeKey)
        }
    }

    private func postBridge(fromChain: Chain, txHash: String, quote: BridgeQuote) async {
        // Report bridge to backend for analytics
        let url = "https://api.rabby.io/v1/bridge/post"
        let params: [String: Any] = [
            "tx_id": txHash,
            "aggregator_id": quote.aggregatorId,
            "bridge_id": quote.bridgeId,
            "from_chain_id": quote.fromChainId,
            "from_token_id": quote.fromToken.id,
            "from_token_amount": quote.fromAmount,
            "to_chain_id": quote.toChainId,
            "to_token_id": quote.toToken.id,
            "to_token_amount": quote.toAmount,
            "rabby_fee": quote.rabbyFee,
        ]

        do {
            let _: BridgePostResponse = try await networkManager.post(url: url, body: params)
        } catch {
            print("[BridgeManager] Failed to post bridge: \(error)")
        }
    }
}

// MARK: - Response Models

private struct BridgePostResponse: Codable {
    let success: Bool?
}

// MARK: - Bridge Status

struct BridgeStatus {
    let status: String // pending, success, failed
    let fromTxHash: String
    let toTxHash: String?
    let estimatedTime: String?
    let actualTime: String?
}

// MARK: - API Response Models

private struct BridgeQuoteResponse: Codable {
    let data: [QuoteData]

    struct QuoteData: Codable {
        let aggregator_id: String
        let aggregator_name: String
        let aggregator_logo: String?
        let bridge_id: String
        let to_token_amount: String
        let estimated_time: String
        let gas_fee: String
        let bridge_fee: String
        let rabby_fee: Double
        let data: String
        let to: String
        let need_approve: Bool
        let spender: String?
    }
}

private struct BridgeStatusResponse: Codable {
    let status: String
    let to_tx_hash: String?
    let estimated_time: String?
    let actual_time: String?
}

/// Response from /v1/bridge/build_tx
private struct BridgeBuildTxResponse: Codable {
    let to: String?
    let data: String?
    let value: String?
    let gas_limit: String?
}

// MARK: - Errors

enum BridgeError: Error, LocalizedError {
    case needApproval(spender: String)
    case approvalFailed(txHash: String)
    case approvalTimeout
    case insufficientBalance
    case quoteNotFound
    case bridgeNotSupported
    case invalidChain
    case buildTxFailed
    case signFailed
    case sendFailed
    case bridgeFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .needApproval(let spender):
            return "Need to approve token for spender: \(spender)"
        case .approvalFailed(let txHash):
            return "Approval transaction failed: \(txHash)"
        case .approvalTimeout:
            return "Approval transaction timed out waiting for confirmation"
        case .insufficientBalance:
            return "Insufficient balance"
        case .quoteNotFound:
            return "No bridge quote found"
        case .bridgeNotSupported:
            return "Bridge not supported for this pair"
        case .invalidChain:
            return "Invalid chain selection"
        case .buildTxFailed:
            return "Failed to build bridge transaction"
        case .signFailed:
            return "Failed to sign bridge transaction"
        case .sendFailed:
            return "Failed to send bridge transaction"
        case .bridgeFailed(let reason):
            return "Bridge failed: \(reason)"
        }
    }
}
