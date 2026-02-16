import Foundation
import Combine
import BigInt

/// NFT Manager - Manage ERC721 and ERC1155 tokens
@MainActor
class NFTManager: ObservableObject {
    static let shared = NFTManager()
    
    @Published var nfts: [NFT] = []
    @Published var collections: [NFTCollection] = []
    @Published var isLoading = false
    
    private let networkManager = NetworkManager.shared
    private let openAPIService = OpenAPIService.shared
    private let storage = StorageManager.shared
    
    private let nftsKey = "rabby_nfts"
    
    // MARK: - Models
    
    struct NFT: Codable, Identifiable {
        let id: String
        let tokenId: String
        let contractAddress: String
        let name: String
        let description: String?
        let image: String?
        let animationUrl: String?
        let externalUrl: String?
        let type: NFTType // ERC721 or ERC1155
        let amount: String? // For ERC1155
        let chain: String
        let collectionName: String?
        let floorPrice: String?
        let lastPrice: String?
        
        enum NFTType: String, Codable {
            case erc721 = "ERC721"
            case erc1155 = "ERC1155"
        }
    }
    
    struct NFTCollection: Codable, Identifiable {
        let id: String
        let name: String
        let description: String?
        let image: String?
        let contractAddress: String
        let chain: String
        let nftCount: Int
        let floorPrice: String?
        let totalVolume: String?
    }
    
    // MARK: - Initialization
    
    private init() {
        loadNFTs()
    }
    
    // MARK: - Public Methods
    
    /// Load NFTs for address
    func loadNFTs(address: String, chain: Chain) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: NFTListResponse = try await openAPIService.get(
                "/v1/user/nft_list",
                params: [
                    "id": address.lowercased(),
                    "chain_id": chain.serverId,
                ]
            )
            
            // Convert to NFT models
            let newNFTs = response.data.map { nftData -> NFT in
                NFT(
                    id: "\(nftData.contract_id)_\(nftData.inner_id)",
                    tokenId: nftData.inner_id,
                    contractAddress: nftData.contract_id,
                    name: nftData.name ?? "Unknown",
                    description: nftData.description,
                    image: nftData.content ?? nftData.thumbnail_url,
                    animationUrl: nftData.animation_url,
                    externalUrl: nftData.external_url,
                    type: nftData.is_erc1155 ? .erc1155 : .erc721,
                    amount: nftData.amount,
                    chain: chain.serverId,
                    collectionName: nftData.collection?.name,
                    floorPrice: nftData.collection?.floor_price,
                    lastPrice: nftData.pay_token?.amount
                )
            }
            
            // Update NFTs
            nfts = newNFTs
            
            // Group into collections
            updateCollections()
            
            saveNFTs()
        } catch {
            print("❌ Failed to load NFTs: \(error)")
            throw error
        }
    }
    
    /// Get NFTs for specific address
    func getNFTs(for address: String, chain: String? = nil) -> [NFT] {
        var filtered = nfts.filter { _ in true } // All NFTs for now
        
        if let chain = chain {
            filtered = filtered.filter { $0.chain == chain }
        }
        
        return filtered
    }
    
    /// Get NFT by token ID and contract
    func getNFT(contractAddress: String, tokenId: String) -> NFT? {
        return nfts.first { nft in
            nft.contractAddress.lowercased() == contractAddress.lowercased() &&
            nft.tokenId == tokenId
        }
    }
    
    /// Get collection by contract address
    func getCollection(contractAddress: String) -> NFTCollection? {
        return collections.first { $0.contractAddress.lowercased() == contractAddress.lowercased() }
    }
    
    // MARK: - Calldata Builders

    /// Build ERC721 safeTransferFrom calldata.
    ///
    /// Function: `safeTransferFrom(address,address,uint256)`
    /// Selector: `0x42842e0e`
    ///
    /// - Parameters:
    ///   - from: sender address
    ///   - to:   recipient address
    ///   - tokenId: the NFT token ID (decimal string)
    /// - Returns: Complete calldata (4-byte selector + ABI-encoded params)
    static func buildERC721TransferCalldata(from: String, to: String, tokenId: String) -> Data {
        // Selector: keccak256("safeTransferFrom(address,address,uint256)")[0..4] = 0x42842e0e
        let selector = Data([0x42, 0x84, 0x2e, 0x0e])

        let fromParam = EthereumUtil.abiEncodeAddress(from)
        let toParam = EthereumUtil.abiEncodeAddress(to)
        let tokenIdParam = EthereumUtil.abiEncodeUint256(BigUInt(tokenId) ?? BigUInt(0))

        return EthereumUtil.abiEncodeFunctionCall(
            selector: selector,
            staticParams: [fromParam, toParam, tokenIdParam]
        )
    }

    /// Build ERC1155 safeTransferFrom calldata.
    ///
    /// Function: `safeTransferFrom(address,address,uint256,uint256,bytes)`
    /// Selector: `0xf242432a`
    ///
    /// ABI layout (after 4-byte selector):
    ///   Offset 0x00: from     (address, 32 bytes)
    ///   Offset 0x20: to       (address, 32 bytes)
    ///   Offset 0x40: tokenId  (uint256, 32 bytes)
    ///   Offset 0x60: amount   (uint256, 32 bytes)
    ///   Offset 0x80: offset to `data` (uint256 = 0xa0 = 160, pointing past the 5 head words)
    ///   Offset 0xa0: length of `data` (uint256 = 0 for empty bytes)
    ///
    /// - Parameters:
    ///   - from:    sender address
    ///   - to:      recipient address
    ///   - tokenId: the NFT token ID (decimal string)
    ///   - amount:  number of tokens to transfer (decimal string, typically "1")
    /// - Returns: Complete calldata
    static func buildERC1155TransferCalldata(from: String, to: String, tokenId: String, amount: String) -> Data {
        // Selector: keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)")[0..4] = 0xf242432a
        let selector = Data([0xf2, 0x42, 0x43, 0x2a])

        let fromParam    = EthereumUtil.abiEncodeAddress(from)
        let toParam      = EthereumUtil.abiEncodeAddress(to)
        let tokenIdParam = EthereumUtil.abiEncodeUint256(BigUInt(tokenId) ?? BigUInt(0))
        let amountParam  = EthereumUtil.abiEncodeUint256(BigUInt(amount) ?? BigUInt(1))

        // The `bytes` parameter is dynamic. Its offset in the head section points to
        // where the dynamic data begins, measured from the start of the parameters
        // (i.e., after the selector). There are 5 head words (5 * 32 = 160 = 0xa0).
        let bytesOffset = EthereumUtil.abiEncodeUint256(BigUInt(160)) // 5 * 32

        // Dynamic tail: empty bytes (length = 0, no data, no padding needed)
        let bytesTail = EthereumUtil.abiEncodeBytes(Data())

        return EthereumUtil.abiEncodeFunctionCall(
            selector: selector,
            staticParams: [fromParam, toParam, tokenIdParam, amountParam, bytesOffset],
            dynamicData: bytesTail
        )
    }

    /// Build ERC1155 safeBatchTransferFrom calldata.
    ///
    /// Function: `safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)`
    /// Selector: `0x2eb2c2d6`
    ///
    /// - Parameters:
    ///   - from:     sender address
    ///   - to:       recipient address
    ///   - tokenIds: array of token IDs (decimal strings)
    ///   - amounts:  array of amounts (decimal strings), must be same length as tokenIds
    /// - Returns: Complete calldata
    static func buildERC1155BatchTransferCalldata(from: String, to: String, tokenIds: [String], amounts: [String]) -> Data {
        // Selector: keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)")[0..4] = 0x2eb2c2d6
        let selector = Data([0x2e, 0xb2, 0xc2, 0xd6])

        // Head section has 5 words: from, to, offset(ids), offset(amounts), offset(data)
        // The three dynamic params (uint256[], uint256[], bytes) need offset pointers.
        //
        // Head layout (5 * 32 = 160 bytes):
        //   [0]  from       (static)
        //   [1]  to         (static)
        //   [2]  offset to tokenIds array
        //   [3]  offset to amounts array
        //   [4]  offset to data bytes

        let fromParam = EthereumUtil.abiEncodeAddress(from)
        let toParam   = EthereumUtil.abiEncodeAddress(to)

        // Build the dynamic sections first so we can compute offsets.
        // tokenIds array: length (32 bytes) + N * 32 bytes
        let tokenIdValues = tokenIds.map { BigUInt($0) ?? BigUInt(0) }
        var tokenIdsEncoded = EthereumUtil.abiEncodeUint256(BigUInt(tokenIdValues.count))
        for val in tokenIdValues {
            tokenIdsEncoded.append(EthereumUtil.abiEncodeUint256(val))
        }

        // amounts array: length (32 bytes) + N * 32 bytes
        let amountValues = amounts.map { BigUInt($0) ?? BigUInt(1) }
        var amountsEncoded = EthereumUtil.abiEncodeUint256(BigUInt(amountValues.count))
        for val in amountValues {
            amountsEncoded.append(EthereumUtil.abiEncodeUint256(val))
        }

        // data bytes: empty
        let dataEncoded = EthereumUtil.abiEncodeBytes(Data())

        // Offsets: measured from start of params (after selector).
        // Head size = 5 * 32 = 160 bytes.
        let headSize = 160
        let tokenIdsOffset = headSize
        let amountsOffset  = tokenIdsOffset + tokenIdsEncoded.count
        let dataOffset     = amountsOffset + amountsEncoded.count

        let tokenIdsOffsetParam = EthereumUtil.abiEncodeUint256(BigUInt(tokenIdsOffset))
        let amountsOffsetParam  = EthereumUtil.abiEncodeUint256(BigUInt(amountsOffset))
        let dataOffsetParam     = EthereumUtil.abiEncodeUint256(BigUInt(dataOffset))

        // Assemble tail
        var dynamicData = Data()
        dynamicData.append(tokenIdsEncoded)
        dynamicData.append(amountsEncoded)
        dynamicData.append(dataEncoded)

        return EthereumUtil.abiEncodeFunctionCall(
            selector: selector,
            staticParams: [fromParam, toParam, tokenIdsOffsetParam, amountsOffsetParam, dataOffsetParam],
            dynamicData: dynamicData
        )
    }

    // MARK: - Send NFT (Unified)

    /// Send an NFT to a recipient, automatically selecting the correct transfer
    /// method based on the NFT type (ERC721 or ERC1155).
    ///
    /// - Parameters:
    ///   - nft:    the NFT to send
    ///   - to:     recipient address
    ///   - from:   sender address
    ///   - amount: number of tokens to transfer (only relevant for ERC1155; ignored for ERC721)
    /// - Returns: transaction hash
    func sendNFT(_ nft: NFT, to: String, from: String, amount: String = "1") async throws -> String {
        let fromAddress = from.trimmingCharacters(in: .whitespacesAndNewlines)
        let toAddress = to.trimmingCharacters(in: .whitespacesAndNewlines)
        let transferAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)

        guard EthereumUtil.isValidAddress(fromAddress) else {
            throw NFTError.invalidSender
        }
        guard EthereumUtil.isValidAddress(toAddress) else {
            throw NFTError.invalidRecipient
        }
        guard EthereumUtil.isValidAddress(nft.contractAddress) else {
            throw NFTError.invalidContract
        }

        guard let chain = resolveChain(for: nft) else {
            throw NFTError.invalidChain
        }

        let calldata: Data

        switch nft.type {
        case .erc721:
            calldata = Self.buildERC721TransferCalldata(
                from: fromAddress,
                to: toAddress,
                tokenId: nft.tokenId
            )
        case .erc1155:
            guard let parsedAmount = BigUInt(transferAmount), parsedAmount > 0 else {
                throw NFTError.invalidAmount
            }
            calldata = Self.buildERC1155TransferCalldata(
                from: fromAddress,
                to: toAddress,
                tokenId: nft.tokenId,
                amount: String(parsedAmount)
            )
        }

        let transaction = try await TransactionManager.shared.buildTransaction(
            from: fromAddress,
            to: nft.contractAddress,
            value: "0x0",
            data: "0x" + calldata.hexString,
            chain: chain
        )

        return try await TransactionManager.shared.sendTransaction(transaction)
    }

    /// Send ERC721 NFT (convenience wrapper).
    func sendERC721(_ nft: NFT, to: String, from: String) async throws -> String {
        guard nft.type == .erc721 else {
            throw NFTError.unsupportedType
        }
        return try await sendNFT(nft, to: to, from: from)
    }

    /// Send ERC1155 NFT with a specified amount.
    func sendERC1155(_ nft: NFT, to: String, from: String, amount: String) async throws -> String {
        guard nft.type == .erc1155 else {
            throw NFTError.unsupportedType
        }
        return try await sendNFT(nft, to: to, from: from, amount: amount)
    }
    
    /// Check if address owns NFT
    func ownsNFT(contractAddress: String, tokenId: String, owner: String, chain: Chain) async throws -> Bool {
        // ERC721 ownerOf function
        // Selector: keccak256("ownerOf(uint256)")[0..4] = 0x6352211e
        let selector = Data([0x63, 0x52, 0x21, 0x1e])
        let tokenIdParam = EthereumUtil.abiEncodeUint256(BigUInt(tokenId) ?? BigUInt(0))
        let callData = EthereumUtil.abiEncodeFunctionCall(
            selector: selector,
            staticParams: [tokenIdParam]
        )
        
        let callTx: [String: Any] = [
            "to": contractAddress,
            "data": "0x" + callData.hexString
        ]
        
        let result: String = try await networkManager.call(
            transaction: callTx,
            chain: chain
        )
        
        // Parse result (address)
        let resultAddress = "0x" + result.suffix(40)
        return resultAddress.lowercased() == owner.lowercased()
    }
    
    // MARK: - Private Methods

    private func resolveChain(for nft: NFT) -> Chain? {
        let chainManager = ChainManager.shared
        if let chain = chainManager.getChain(serverId: nft.chain) {
            return chain
        }
        if let chainId = Int(nft.chain), let chain = chainManager.getChain(byId: chainId) {
            return chain
        }
        return nil
    }
    
    private func updateCollections() {
        // Group NFTs by contract address
        let grouped = Dictionary(grouping: nfts) { $0.contractAddress }
        
        collections = grouped.map { contractAddress, nfts in
            let firstNFT = nfts.first!
            
            return NFTCollection(
                id: contractAddress,
                name: firstNFT.collectionName ?? "Unknown Collection",
                description: nil,
                image: nfts.first?.image,
                contractAddress: contractAddress,
                chain: firstNFT.chain,
                nftCount: nfts.count,
                floorPrice: firstNFT.floorPrice,
                totalVolume: nil
            )
        }
    }
    
    private func loadNFTs() {
        if let data = storage.getData(forKey: nftsKey),
           let nfts = try? JSONDecoder().decode([NFT].self, from: data) {
            self.nfts = nfts
            updateCollections()
        }
    }
    
    private func saveNFTs() {
        if let data = try? JSONEncoder().encode(nfts) {
            storage.setData(data, forKey: nftsKey)
        }
    }
}

// MARK: - API Response Models

private struct NFTListResponse: Codable {
    let data: [NFTData]
    
    struct NFTData: Codable {
        let contract_id: String
        let inner_id: String
        let name: String?
        let description: String?
        let content: String?
        let thumbnail_url: String?
        let animation_url: String?
        let external_url: String?
        let is_erc1155: Bool
        let amount: String?
        let collection: Collection?
        let pay_token: PayToken?
        
        struct Collection: Codable {
            let name: String
            let floor_price: String?
        }
        
        struct PayToken: Codable {
            let amount: String
        }
    }
}

// MARK: - UInt256 Helper

/// A simple 32-byte big-endian representation for uint256 values.
/// Backed by BigUInt so it can handle token IDs that exceed UInt64 range.
struct UInt256 {
    let data: Data

    init?(_ string: String) {
        guard let value = BigUInt(string) else { return nil }
        self.data = value.toPaddedData(length: 32)
    }

    init(_ value: BigUInt) {
        self.data = value.toPaddedData(length: 32)
    }
}

// MARK: - Errors

enum NFTError: Error, LocalizedError {
    case unsupportedType
    case notFound
    case transferFailed
    case invalidSender
    case invalidRecipient
    case invalidContract
    case invalidAmount
    case invalidChain
    
    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Unsupported NFT type"
        case .notFound:
            return "NFT not found"
        case .transferFailed:
            return "Failed to transfer NFT"
        case .invalidSender:
            return "Invalid sender address"
        case .invalidRecipient:
            return "Invalid recipient address"
        case .invalidContract:
            return "Invalid NFT contract address"
        case .invalidAmount:
            return "Invalid NFT amount"
        case .invalidChain:
            return "Unsupported NFT chain"
        }
    }
}
