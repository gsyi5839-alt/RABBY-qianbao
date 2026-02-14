import Foundation
import BigInt

// MARK: - Transaction Action Models

/// Represents a parsed, human-readable transaction action derived from raw calldata.
/// Covers all common on-chain operations: transfers, approvals, swaps, bridging, NFTs, etc.
enum TransactionAction {
    case send(SendAction)                    // ETH/Token transfer
    case tokenApprove(ApproveAction)         // ERC20 approval
    case revokeApprove(RevokeAction)         // Revoke approval (approve with amount 0)
    case swap(SwapAction)                    // DEX swap
    case crossSwap(CrossSwapAction)          // Cross-chain swap
    case crossTransfer(CrossTransferAction)  // Cross-chain transfer
    case addLiquidity(LiquidityAction)       // Add liquidity to pool
    case wrapToken(WrapAction)               // WETH deposit (wrap)
    case unwrapToken(WrapAction)             // WETH withdraw (unwrap)
    case contractCall(ContractCallAction)    // Generic contract interaction
    case deployContract                      // Contract deployment (to == nil)
    case cancelTx(CancelAction)             // Cancel transaction (self-transfer with 0 value)
    case sendNFT(SendNFTAction)             // NFT transfer (ERC721 / ERC1155)
    case approveNFT(ApproveNFTAction)       // NFT approval
    case unknown(to: String, data: String)   // Unrecognised calldata
}

// MARK: - Action Structs

/// Native ETH or ERC20 token transfer.
struct SendAction {
    let to: String
    let amount: String
    let symbol: String
    let tokenAddress: String?
    let usdValue: Double?
}

/// ERC20 `approve(spender, amount)`.
struct ApproveAction {
    let spender: String
    let spenderName: String?
    let token: String
    let symbol: String
    let amount: String
    let isUnlimited: Bool
}

/// Revoke an ERC20 approval (approve with amount == 0).
struct RevokeAction {
    let spender: String
    let spenderName: String?
    let token: String
    let symbol: String
}

/// DEX token swap.
struct SwapAction {
    let fromToken: String
    let toToken: String
    let fromAmount: String
    let toAmount: String
    let dex: String?
}

/// Cross-chain swap via bridge aggregator.
struct CrossSwapAction {
    let fromChain: String
    let toChain: String
    let fromToken: String
    let toToken: String
    let fromAmount: String
    let toAmount: String
    let bridge: String?
}

/// Cross-chain native/token transfer.
struct CrossTransferAction {
    let fromChain: String
    let toChain: String
    let token: String
    let amount: String
    let receiver: String
    let bridge: String?
}

/// Add liquidity to a DeFi pool.
struct LiquidityAction {
    let tokenA: String
    let tokenB: String
    let amountA: String
    let amountB: String
    let protocol_: String?
}

/// WETH wrap / unwrap.
struct WrapAction {
    let token: String
    let amount: String
    let isWrap: Bool
}

/// Generic contract call that does not match any known selector.
struct ContractCallAction {
    let to: String
    let selector: String
    let methodName: String?
    let value: String
}

/// Cancel a pending transaction (self-transfer with value 0).
struct CancelAction {
    let from: String
    let nonce: String?
}

/// NFT transfer (ERC721 / ERC1155).
struct SendNFTAction {
    let to: String
    let contractAddress: String
    let tokenId: String
    let amount: String?       // ERC1155 quantity (nil for ERC721)
    let nftName: String?
    let standard: NFTStandard

    enum NFTStandard: String {
        case erc721 = "ERC-721"
        case erc1155 = "ERC-1155"
    }
}

/// NFT approval (ERC721 `approve` or `setApprovalForAll`).
struct ApproveNFTAction {
    let spender: String
    let spenderName: String?
    let contractAddress: String
    let tokenId: String?       // nil for setApprovalForAll
    let isApprovedForAll: Bool
}

// MARK: - Well-Known Function Selectors

/// 4-byte function selectors for common EVM methods.
private enum Selector {
    // ERC20
    static let transfer            = "0xa9059cbb" // transfer(address,uint256)
    static let approve             = "0x095ea7b3" // approve(address,uint256)
    static let transferFrom        = "0x23b872dd" // transferFrom(address,address,uint256)

    // ERC721
    static let safeTransferFrom721 = "0x42842e0e" // safeTransferFrom(address,address,uint256)
    static let approveNFT          = "0x095ea7b3" // same as ERC20 approve
    static let setApprovalForAll   = "0xa22cb465" // setApprovalForAll(address,bool)

    // ERC1155
    static let safeTransferFrom1155 = "0xf242432a" // safeTransferFrom(address,address,uint256,uint256,bytes)

    // WETH
    static let deposit             = "0xd0e30db0" // deposit()
    static let withdraw            = "0x2e1a7d4d" // withdraw(uint256)

    // Common DEX routers
    static let swapExactTokensForTokens           = "0x38ed1739"
    static let swapExactETHForTokens              = "0x7ff36ab5"
    static let swapExactTokensForETH              = "0x18cbafe5"
    static let swapExactTokensForTokensFee        = "0x5c11d795"
    static let uniswapV3Execute                   = "0x3593564c" // Universal Router execute
    static let oneInchSwap                        = "0x0162e2d0"

    // Liquidity
    static let addLiquidity        = "0xe8e33700" // addLiquidity(...)
    static let addLiquidityETH     = "0xf305d719" // addLiquidityETH(...)
}

// MARK: - Comprehensive Method Selector Dictionary

/// Maps 4-byte selectors to human-readable method names.
/// Covers the most frequently encountered EVM function signatures.
private let selectorToMethodName: [String: String] = [
    // ERC20
    Selector.transfer:               "transfer(address,uint256)",
    Selector.approve:                "approve(address,uint256)",
    Selector.transferFrom:           "transferFrom(address,address,uint256)",

    // ERC721
    Selector.safeTransferFrom721:    "safeTransferFrom(address,address,uint256)",
    Selector.setApprovalForAll:      "setApprovalForAll(address,bool)",

    // ERC1155
    Selector.safeTransferFrom1155:   "safeTransferFrom(address,address,uint256,uint256,bytes)",

    // WETH
    Selector.deposit:                "deposit()",
    Selector.withdraw:               "withdraw(uint256)",

    // Uniswap V2 Router
    Selector.swapExactTokensForTokens:        "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
    Selector.swapExactETHForTokens:           "swapExactETHForTokens(uint256,address[],address,uint256)",
    Selector.swapExactTokensForETH:           "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
    Selector.swapExactTokensForTokensFee:     "swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)",

    // Uniswap Universal Router
    Selector.uniswapV3Execute:       "execute(bytes,bytes[],uint256)",

    // 1inch
    Selector.oneInchSwap:            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",

    // Liquidity
    Selector.addLiquidity:           "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
    Selector.addLiquidityETH:        "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
]

// MARK: - TransactionActionParser

/// Parses raw Ethereum transaction data into human-readable `TransactionAction` values.
///
/// Two parsing strategies are available:
/// 1. **Offline / local** (`parse`): Uses the function selector (first 4 bytes of calldata)
///    together with basic ABI decoding. Fast but limited in detail.
/// 2. **Pre-execution enriched** (`parseWithPreExec`): Uses the result of an RPC
///    `eth_call` / Rabby backend pre-execution to provide richer information such as
///    token symbols, USD values, and counterparty names.
@MainActor
final class TransactionActionParser {

    static let shared = TransactionActionParser()

    // MARK: - Known WETH addresses (lowercase, without 0x prefix for fast lookup)

    /// Commonly deployed WETH contracts indexed by chain ID string.
    private let wethAddresses: [String: String] = [
        "1":      "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", // Ethereum
        "10":     "0x4200000000000000000000000000000000000006", // Optimism
        "56":     "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c", // BSC (WBNB)
        "137":    "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270", // Polygon (WMATIC)
        "250":    "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83", // Fantom (WFTM)
        "42161":  "0x82af49447d8a07e3bd95bd0d56f35241523fbab1", // Arbitrum
        "43114":  "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7", // Avalanche (WAVAX)
        "8453":   "0x4200000000000000000000000000000000000006", // Base
        "324":    "0x5aea5775959fbc2557cc8789bc1bf90a239d9a91", // zkSync Era
        "59144":  "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f", // Linea
    ]

    // MARK: - Public API

    /// Parse a transaction locally using the function selector and basic ABI decoding.
    ///
    /// - Parameters:
    ///   - to: The destination address of the transaction (nil for contract deployment).
    ///   - value: The transaction value in wei as a hex string (e.g. "0x0" or "0xde0b6b3a7640000").
    ///   - data: The calldata hex string (e.g. "0xa9059cbb000...").
    ///   - chainId: The chain ID as a string (e.g. "1" for Ethereum mainnet).
    ///   - from: The sender address (optional, used for cancel-tx detection).
    /// - Returns: A `TransactionAction` describing the transaction intent.
    func parse(
        to: String?,
        value: String,
        data: String,
        chainId: String,
        from: String? = nil
    ) -> TransactionAction {

        // 1. Contract deployment: no `to` address
        guard let toAddress = to, !toAddress.isEmpty else {
            return .deployContract
        }

        let cleanData = normalizeHex(data)
        let selector = extractSelector(from: cleanData)
        let weiValue = hexToBigUInt(value)

        // 2. Cancel transaction: self-transfer with zero value and no meaningful data
        if let sender = from,
           sender.lowercased() == toAddress.lowercased(),
           weiValue == 0,
           (cleanData == "0x" || cleanData.isEmpty || cleanData.count <= 2) {
            return .cancelTx(CancelAction(from: sender, nonce: nil))
        }

        // 3. Plain ETH transfer: empty data or just "0x"
        if cleanData.count <= 2 || cleanData == "0x" {
            let ethAmount = formatAmount(weiValue, decimals: 18)
            return .send(SendAction(
                to: toAddress,
                amount: ethAmount,
                symbol: "ETH",
                tokenAddress: nil,
                usdValue: nil
            ))
        }

        // 4. Selector-based routing
        guard let sel = selector else {
            return .unknown(to: toAddress, data: cleanData)
        }

        switch sel {

        // ── ERC20 transfer ──────────────────────────────────────────────
        case Selector.transfer:
            let params = decodeABIParams(data: cleanData, types: ["address", "uint256"])
            let recipient = params.count > 0 ? formatABIAddress(params[0]) : toAddress
            let rawAmount = params.count > 1 ? params[1] : "0"
            return .send(SendAction(
                to: recipient,
                amount: rawAmount,
                symbol: "ERC20",
                tokenAddress: toAddress,
                usdValue: nil
            ))

        // ── ERC20 approve ───────────────────────────────────────────────
        case Selector.approve:
            let params = decodeABIParams(data: cleanData, types: ["address", "uint256"])
            let spender = params.count > 0 ? formatABIAddress(params[0]) : ""
            let rawAmount = params.count > 1 ? params[1] : "0"
            let amountBig = hexToBigUInt(rawAmount)

            if amountBig == 0 {
                return .revokeApprove(RevokeAction(
                    spender: spender,
                    spenderName: nil,
                    token: toAddress,
                    symbol: "ERC20"
                ))
            }

            let isUnlimited = isMaxUint256(rawAmount)
            return .tokenApprove(ApproveAction(
                spender: spender,
                spenderName: nil,
                token: toAddress,
                symbol: "ERC20",
                amount: isUnlimited ? "Unlimited" : rawAmount,
                isUnlimited: isUnlimited
            ))

        // ── ERC20 transferFrom ──────────────────────────────────────────
        case Selector.transferFrom:
            let params = decodeABIParams(data: cleanData, types: ["address", "address", "uint256"])
            let recipient = params.count > 1 ? formatABIAddress(params[1]) : toAddress
            let rawAmount = params.count > 2 ? params[2] : "0"
            return .send(SendAction(
                to: recipient,
                amount: rawAmount,
                symbol: "ERC20",
                tokenAddress: toAddress,
                usdValue: nil
            ))

        // ── ERC721 safeTransferFrom(address,address,uint256) ────────────
        case Selector.safeTransferFrom721:
            let params = decodeABIParams(data: cleanData, types: ["address", "address", "uint256"])
            let recipient = params.count > 1 ? formatABIAddress(params[1]) : ""
            let tokenId = params.count > 2 ? params[2] : "0"
            return .sendNFT(SendNFTAction(
                to: recipient,
                contractAddress: toAddress,
                tokenId: tokenId,
                amount: nil,
                nftName: nil,
                standard: .erc721
            ))

        // ── ERC1155 safeTransferFrom(address,address,uint256,uint256,bytes) ─
        case Selector.safeTransferFrom1155:
            let params = decodeABIParams(data: cleanData, types: ["address", "address", "uint256", "uint256"])
            let recipient = params.count > 1 ? formatABIAddress(params[1]) : ""
            let tokenId = params.count > 2 ? params[2] : "0"
            let amount = params.count > 3 ? params[3] : "1"
            return .sendNFT(SendNFTAction(
                to: recipient,
                contractAddress: toAddress,
                tokenId: tokenId,
                amount: amount,
                nftName: nil,
                standard: .erc1155
            ))

        // ── setApprovalForAll(address,bool) ─────────────────────────────
        case Selector.setApprovalForAll:
            let params = decodeABIParams(data: cleanData, types: ["address", "uint256"])
            let spender = params.count > 0 ? formatABIAddress(params[0]) : ""
            let approved = params.count > 1 ? (hexToBigUInt(params[1]) != 0) : true
            if !approved {
                // Revoking NFT approval for all
                return .revokeApprove(RevokeAction(
                    spender: spender,
                    spenderName: nil,
                    token: toAddress,
                    symbol: "NFT Collection"
                ))
            }
            return .approveNFT(ApproveNFTAction(
                spender: spender,
                spenderName: nil,
                contractAddress: toAddress,
                tokenId: nil,
                isApprovedForAll: true
            ))

        // ── WETH deposit (wrap) ─────────────────────────────────────────
        case Selector.deposit:
            let isWETH = isWrappedNativeToken(address: toAddress, chainId: chainId)
            if isWETH {
                let ethAmount = formatAmount(weiValue, decimals: 18)
                return .wrapToken(WrapAction(token: "ETH", amount: ethAmount, isWrap: true))
            }
            // Fallthrough to generic contract call
            return makeContractCall(to: toAddress, selector: sel, value: value)

        // ── WETH withdraw (unwrap) ──────────────────────────────────────
        case Selector.withdraw:
            let isWETH = isWrappedNativeToken(address: toAddress, chainId: chainId)
            if isWETH {
                let params = decodeABIParams(data: cleanData, types: ["uint256"])
                let rawAmount = params.first ?? "0"
                let amount = formatAmount(hexToBigUInt(rawAmount), decimals: 18)
                return .unwrapToken(WrapAction(token: "WETH", amount: amount, isWrap: false))
            }
            return makeContractCall(to: toAddress, selector: sel, value: value)

        // ── DEX Swap selectors ──────────────────────────────────────────
        case Selector.swapExactTokensForTokens,
             Selector.swapExactETHForTokens,
             Selector.swapExactTokensForETH,
             Selector.swapExactTokensForTokensFee,
             Selector.uniswapV3Execute,
             Selector.oneInchSwap:
            return .swap(SwapAction(
                fromToken: "Token",
                toToken: "Token",
                fromAmount: weiValue > 0 ? formatAmount(weiValue, decimals: 18) : "?",
                toAmount: "?",
                dex: dexName(for: sel)
            ))

        // ── Add Liquidity ───────────────────────────────────────────────
        case Selector.addLiquidity, Selector.addLiquidityETH:
            return .addLiquidity(LiquidityAction(
                tokenA: "Token",
                tokenB: "Token",
                amountA: "?",
                amountB: "?",
                protocol_: nil
            ))

        default:
            return makeContractCall(to: toAddress, selector: sel, value: value)
        }
    }

    /// Parse a transaction using pre-execution results from the Rabby backend.
    ///
    /// The `preExecResult` dictionary is expected to follow the shape returned by the
    /// Rabby OpenAPI `/v1/engine/preexec` endpoint, which contains token balance changes,
    /// protocol identification, and risk data.
    ///
    /// - Parameters:
    ///   - tx: Raw transaction dictionary with keys `from`, `to`, `value`, `data`, `chainId`.
    ///   - preExecResult: Pre-execution result dictionary from the backend.
    /// - Returns: A `TransactionAction` enriched with token symbols, USD values, etc.
    func parseWithPreExec(tx: [String: Any], preExecResult: [String: Any]) -> TransactionAction {
        let from = tx["from"] as? String
        let to = tx["to"] as? String
        let value = tx["value"] as? String ?? "0x0"
        let data = tx["data"] as? String ?? "0x"
        let chainId = tx["chainId"] as? String ?? "1"

        // Extract balance change from pre-exec result
        let balanceChange = preExecResult["balance_change"] as? [String: Any]
        let sendTokenList = balanceChange?["send_token_list"] as? [[String: Any]] ?? []
        let receiveTokenList = balanceChange?["receive_token_list"] as? [[String: Any]] ?? []
        let sendNFTList = balanceChange?["send_nft_list"] as? [[String: Any]] ?? []
        let _ = balanceChange?["receive_nft_list"] as? [[String: Any]] ?? []

        // Extract pre-exec action type if available
        let preExecType = preExecResult["type_call"] as? [String: Any]
        let actionType = preExecType?["action"] as? String

        // Use pre-exec action type to enrich the base parse
        let baseAction = parse(to: to, value: value, data: data, chainId: chainId, from: from)

        // Enrich based on balance changes and action type
        switch baseAction {

        // ── Enrich ERC20 transfer with symbol & USD value ───────────────
        case .send(let sendAction):
            if let firstSend = sendTokenList.first {
                let symbol = firstSend["symbol"] as? String ?? sendAction.symbol
                let amount = firstSend["amount"] as? Double
                let usdValue = firstSend["usd_value"] as? Double
                return .send(SendAction(
                    to: sendAction.to,
                    amount: amount != nil ? formatDecimalAmount(amount!) : sendAction.amount,
                    symbol: symbol,
                    tokenAddress: sendAction.tokenAddress,
                    usdValue: usdValue
                ))
            }
            return baseAction

        // ── Enrich approval with spender name ───────────────────────────
        case .tokenApprove(let approveAction):
            let spenderProtocol = preExecResult["spender_protocol"] as? [String: Any]
            let spenderName = spenderProtocol?["name"] as? String
            let tokenInfo = preExecResult["token"] as? [String: Any]
            let symbol = tokenInfo?["symbol"] as? String ?? approveAction.symbol
            return .tokenApprove(ApproveAction(
                spender: approveAction.spender,
                spenderName: spenderName ?? approveAction.spenderName,
                token: approveAction.token,
                symbol: symbol,
                amount: approveAction.amount,
                isUnlimited: approveAction.isUnlimited
            ))

        // ── Enrich revoke with spender name ─────────────────────────────
        case .revokeApprove(let revokeAction):
            let spenderProtocol = preExecResult["spender_protocol"] as? [String: Any]
            let spenderName = spenderProtocol?["name"] as? String
            let tokenInfo = preExecResult["token"] as? [String: Any]
            let symbol = tokenInfo?["symbol"] as? String ?? revokeAction.symbol
            return .revokeApprove(RevokeAction(
                spender: revokeAction.spender,
                spenderName: spenderName ?? revokeAction.spenderName,
                token: revokeAction.token,
                symbol: symbol
            ))

        // ── Detect swap from balance changes ────────────────────────────
        case .contractCall, .swap:
            if !sendTokenList.isEmpty && !receiveTokenList.isEmpty {
                let fromSymbol = sendTokenList.first?["symbol"] as? String ?? "Token"
                let toSymbol = receiveTokenList.first?["symbol"] as? String ?? "Token"
                let fromAmount = sendTokenList.first?["amount"] as? Double
                let toAmount = receiveTokenList.first?["amount"] as? Double
                let protocol_ = preExecResult["protocol"] as? [String: Any]
                let dexName = protocol_?["name"] as? String

                // Check cross-chain indicators
                if actionType == "cross_swap" || actionType == "cross_token_approval" {
                    let fromChain = sendTokenList.first?["chain"] as? String ?? chainId
                    let toChain = receiveTokenList.first?["chain"] as? String ?? chainId
                    if fromChain != toChain {
                        return .crossSwap(CrossSwapAction(
                            fromChain: fromChain,
                            toChain: toChain,
                            fromToken: fromSymbol,
                            toToken: toSymbol,
                            fromAmount: fromAmount != nil ? formatDecimalAmount(fromAmount!) : "?",
                            toAmount: toAmount != nil ? formatDecimalAmount(toAmount!) : "?",
                            bridge: dexName
                        ))
                    }
                }

                return .swap(SwapAction(
                    fromToken: fromSymbol,
                    toToken: toSymbol,
                    fromAmount: fromAmount != nil ? formatDecimalAmount(fromAmount!) : "?",
                    toAmount: toAmount != nil ? formatDecimalAmount(toAmount!) : "?",
                    dex: dexName
                ))
            }

            // Cross-chain transfer (send only, different chains)
            if !sendTokenList.isEmpty && receiveTokenList.isEmpty {
                if actionType == "cross_transfer" {
                    let fromChain = sendTokenList.first?["chain"] as? String ?? chainId
                    let toChain = preExecResult["to_chain"] as? String ?? chainId
                    let symbol = sendTokenList.first?["symbol"] as? String ?? "Token"
                    let amount = sendTokenList.first?["amount"] as? Double
                    return .crossTransfer(CrossTransferAction(
                        fromChain: fromChain,
                        toChain: toChain,
                        token: symbol,
                        amount: amount != nil ? formatDecimalAmount(amount!) : "?",
                        receiver: to ?? "",
                        bridge: nil
                    ))
                }
            }

            // NFT send detected from balance changes
            if !sendNFTList.isEmpty {
                let nft = sendNFTList.first!
                let nftName = nft["name"] as? String
                let contractAddress = nft["contract_id"] as? String ?? to ?? ""
                let tokenId = nft["inner_id"] as? String ?? "0"
                return .sendNFT(SendNFTAction(
                    to: to ?? "",
                    contractAddress: contractAddress,
                    tokenId: tokenId,
                    amount: nil,
                    nftName: nftName,
                    standard: .erc721
                ))
            }

            return baseAction

        // ── Enrich NFT send with name ───────────────────────────────────
        case .sendNFT(let nftAction):
            if let firstNFT = sendNFTList.first {
                let nftName = firstNFT["name"] as? String
                return .sendNFT(SendNFTAction(
                    to: nftAction.to,
                    contractAddress: nftAction.contractAddress,
                    tokenId: nftAction.tokenId,
                    amount: nftAction.amount,
                    nftName: nftName ?? nftAction.nftName,
                    standard: nftAction.standard
                ))
            }
            return baseAction

        default:
            return baseAction
        }
    }

    // MARK: - Public Helpers

    /// Look up the human-readable method name for a 4-byte function selector.
    ///
    /// - Parameter selector: The selector as a hex string (e.g. "0xa9059cbb").
    /// - Returns: The method signature if known, otherwise nil.
    func getMethodName(selector: String) -> String? {
        let normalized = normalizeSelector(selector)
        return selectorToMethodName[normalized]
    }

    /// Decode ABI-encoded parameters from calldata.
    ///
    /// Each static parameter occupies a 32-byte (64 hex character) word following the
    /// 4-byte selector. Dynamic types (bytes, string, arrays) are NOT fully decoded;
    /// instead the raw hex of the head word (offset) is returned.
    ///
    /// - Parameters:
    ///   - data: Full calldata hex string including the 4-byte selector.
    ///   - types: Array of expected Solidity type names (e.g. ["address", "uint256"]).
    /// - Returns: Array of decoded parameter values as hex strings.
    func decodeABIParams(data: String, types: [String]) -> [String] {
        let cleaned = normalizeHex(data)
        // Remove "0x" prefix and 4-byte selector (8 hex chars)
        guard cleaned.count > 10 else { return [] }
        let paramsHex = String(cleaned.dropFirst(10))

        var results: [String] = []
        for (index, type) in types.enumerated() {
            let offset = index * 64
            guard offset + 64 <= paramsHex.count else { break }
            let start = paramsHex.index(paramsHex.startIndex, offsetBy: offset)
            let end = paramsHex.index(start, offsetBy: 64)
            let word = String(paramsHex[start..<end])

            switch type {
            case "address":
                // Address is the last 40 chars of the 32-byte word
                let addrStart = word.index(word.startIndex, offsetBy: 24)
                results.append("0x" + String(word[addrStart...]))
            case "uint256", "uint128", "uint64", "uint32", "uint16", "uint8", "int256":
                results.append("0x" + word)
            case "bool":
                let boolVal = word.hasSuffix("1") ? "1" : "0"
                results.append(boolVal)
            default:
                results.append("0x" + word)
            }
        }

        return results
    }

    /// Format a raw token amount (BigUInt) using the given number of decimals.
    ///
    /// - Parameters:
    ///   - raw: The raw amount as a hex string (e.g. "0xde0b6b3a7640000") or decimal string.
    ///   - decimals: Token decimal places (e.g. 18 for ETH, 6 for USDC).
    /// - Returns: A human-readable decimal string (e.g. "1.0").
    func formatAmount(_ raw: String, decimals: Int) -> String {
        let bigValue = hexToBigUInt(raw)
        return formatAmount(bigValue, decimals: decimals)
    }

    // MARK: - Human-Readable Description

    /// Generate a concise, human-readable description of a `TransactionAction`.
    func describe(_ action: TransactionAction) -> String {
        switch action {
        case .send(let a):
            return "Send \(a.amount) \(a.symbol) to \(EthereumUtil.formatAddress(a.to))"

        case .tokenApprove(let a):
            let who = a.spenderName ?? EthereumUtil.formatAddress(a.spender)
            if a.isUnlimited {
                return "Approve unlimited \(a.symbol) to \(who)"
            }
            return "Approve \(a.amount) \(a.symbol) to \(who)"

        case .revokeApprove(let a):
            let who = a.spenderName ?? EthereumUtil.formatAddress(a.spender)
            return "Revoke \(a.symbol) approval from \(who)"

        case .swap(let a):
            let dex = a.dex.map { " on \($0)" } ?? ""
            return "Swap \(a.fromAmount) \(a.fromToken) → \(a.toAmount) \(a.toToken)\(dex)"

        case .crossSwap(let a):
            let bridge = a.bridge.map { " via \($0)" } ?? ""
            return "Cross-chain swap \(a.fromAmount) \(a.fromToken) (\(a.fromChain)) → \(a.toAmount) \(a.toToken) (\(a.toChain))\(bridge)"

        case .crossTransfer(let a):
            let bridge = a.bridge.map { " via \($0)" } ?? ""
            return "Bridge \(a.amount) \(a.token) from \(a.fromChain) to \(a.toChain)\(bridge)"

        case .addLiquidity(let a):
            let proto = a.protocol_.map { " on \($0)" } ?? ""
            return "Add liquidity \(a.amountA) \(a.tokenA) + \(a.amountB) \(a.tokenB)\(proto)"

        case .wrapToken(let a):
            return "Wrap \(a.amount) \(a.token) → W\(a.token)"

        case .unwrapToken(let a):
            return "Unwrap \(a.amount) \(a.token) → \(a.token.replacingOccurrences(of: "W", with: ""))"

        case .contractCall(let a):
            let method = a.methodName ?? a.selector
            return "Call \(method) on \(EthereumUtil.formatAddress(a.to))"

        case .deployContract:
            return "Deploy new contract"

        case .cancelTx(let a):
            let nonce = a.nonce.map { " (nonce \($0))" } ?? ""
            return "Cancel transaction\(nonce)"

        case .sendNFT(let a):
            let name = a.nftName ?? "\(a.standard.rawValue) #\(a.tokenId)"
            return "Send NFT \(name) to \(EthereumUtil.formatAddress(a.to))"

        case .approveNFT(let a):
            let who = a.spenderName ?? EthereumUtil.formatAddress(a.spender)
            if a.isApprovedForAll {
                return "Approve all NFTs in collection to \(who)"
            }
            return "Approve NFT #\(a.tokenId ?? "?") to \(who)"

        case .unknown(let to, _):
            return "Unknown action on \(EthereumUtil.formatAddress(to))"
        }
    }

    // MARK: - Private Helpers

    /// Normalize a hex string to always start with "0x".
    private func normalizeHex(_ hex: String) -> String {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "0x" }
        return trimmed.hasPrefix("0x") ? trimmed.lowercased() : "0x" + trimmed.lowercased()
    }

    /// Normalize a 4-byte selector to lowercase with "0x" prefix.
    private func normalizeSelector(_ selector: String) -> String {
        let norm = normalizeHex(selector)
        guard norm.count >= 10 else { return norm }
        return String(norm.prefix(10))
    }

    /// Extract the 4-byte function selector from calldata.
    private func extractSelector(from data: String) -> String? {
        let cleaned = normalizeHex(data)
        guard cleaned.count >= 10 else { return nil }
        return String(cleaned.prefix(10))
    }

    /// Convert a hex string to BigUInt.
    private func hexToBigUInt(_ hex: String) -> BigUInt {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("0x") || cleaned.hasPrefix("0X") {
            return BigUInt(String(cleaned.dropFirst(2)), radix: 16) ?? 0
        }
        // Try decimal string
        return BigUInt(cleaned) ?? 0
    }

    /// Format a BigUInt amount with the given number of decimals into a decimal string.
    private func formatAmount(_ raw: BigUInt, decimals: Int) -> String {
        guard decimals > 0 else {
            return raw.description
        }

        let divisor = BigUInt(10).power(decimals)
        let wholePart = raw / divisor
        let remainder = raw % divisor

        if remainder == 0 {
            return wholePart.description
        }

        let remainderStr = remainder.description
        let paddedRemainder = String(repeating: "0", count: max(0, decimals - remainderStr.count)) + remainderStr
        // Trim trailing zeros
        let trimmed = paddedRemainder.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        if trimmed.isEmpty {
            return wholePart.description
        }
        return "\(wholePart).\(trimmed)"
    }

    /// Format a Double amount to a reasonable decimal string.
    private func formatDecimalAmount(_ value: Double) -> String {
        if value == 0 { return "0" }
        if abs(value) >= 1 {
            return String(format: "%.4f", value)
                .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
        }
        return String(format: "%.8f", value)
            .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }

    /// Format a raw ABI address parameter (40 hex chars) to checksum form.
    private func formatABIAddress(_ raw: String) -> String {
        let cleaned = normalizeHex(raw)
        guard EthereumUtil.isValidAddress(cleaned) else { return cleaned }
        return EthereumUtil.toChecksumAddress(cleaned)
    }

    /// Check if a hex amount represents the uint256 max value (unlimited approval).
    private func isMaxUint256(_ hex: String) -> Bool {
        let value = hexToBigUInt(hex)
        // uint256 max = 2^256 - 1
        let maxUint256 = (BigUInt(1) << 256) - 1
        // Consider "unlimited" if value >= 2^255 (common threshold)
        let unlimitedThreshold = BigUInt(1) << 255
        return value >= unlimitedThreshold || value == maxUint256
    }

    /// Check whether the given address is the wrapped native token (WETH/WBNB/WMATIC/...)
    /// for the specified chain.
    private func isWrappedNativeToken(address: String, chainId: String) -> Bool {
        guard let weth = wethAddresses[chainId] else { return false }
        return address.lowercased() == weth.lowercased()
    }

    /// Map a swap selector to a human-readable DEX name.
    private func dexName(for selector: String) -> String? {
        switch selector {
        case Selector.swapExactTokensForTokens,
             Selector.swapExactETHForTokens,
             Selector.swapExactTokensForETH,
             Selector.swapExactTokensForTokensFee:
            return "Uniswap V2"
        case Selector.uniswapV3Execute:
            return "Uniswap (Universal Router)"
        case Selector.oneInchSwap:
            return "1inch"
        default:
            return nil
        }
    }

    /// Create a generic contract-call action.
    private func makeContractCall(to: String, selector: String, value: String) -> TransactionAction {
        return .contractCall(ContractCallAction(
            to: to,
            selector: selector,
            methodName: getMethodName(selector: selector),
            value: value
        ))
    }
}
