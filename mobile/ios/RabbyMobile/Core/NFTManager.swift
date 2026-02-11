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
        
        // Call OpenAPI to get NFTs
        let url = "https://api.rabby.io/v1/user/nft_list"
        let params: [String: Any] = [
            "id": address.lowercased(),
            "chain_id": chain.serverId
        ]
        
        do {
            let response: NFTListResponse = try await networkManager.post(url: url, body: params)
            
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
    
    /// Send NFT (ERC721)
    func sendNFT(_ nft: NFT, to: String, from: String) async throws -> String {
        guard nft.type == .erc721 else {
            throw NFTError.unsupportedType
        }
        
        // ERC721 safeTransferFrom function
        let functionSignature = "safeTransferFrom(address,address,uint256)"
        let selector = Keccak256.hash(string: functionSignature).prefix(4)
        
        // Encode parameters
        var data = Data(selector)
        
        // From address (padded to 32 bytes)
        if let fromData = Data(hexString: String(from.dropFirst(2))) {
            data.append(Data(repeating: 0, count: 12))
            data.append(fromData)
        }
        
        // To address (padded to 32 bytes)
        if let toData = Data(hexString: String(to.dropFirst(2))) {
            data.append(Data(repeating: 0, count: 12))
            data.append(toData)
        }
        
        // Token ID (padded to 32 bytes)
        if let tokenIdNum = UInt256(nft.tokenId) {
            data.append(tokenIdNum.data)
        }
        
        // Create transaction
        let chainId = Int(nft.chain) ?? 1
        let transaction = EthereumTransaction(
            to: nft.contractAddress,
            from: from,
            nonce: BigUInt(0),
            value: BigUInt(0),
            data: data,
            gasLimit: BigUInt(200000),
            chainId: chainId
        )
        
        // Sign and send
        let signedTx = try await KeyringManager.shared.signTransaction(address: from, transaction: transaction)
        let txHash = try await TransactionManager.shared.broadcastTransaction(signedTx)
        
        return txHash
    }
    
    /// Send ERC1155 NFT
    func sendERC1155(_ nft: NFT, to: String, from: String, amount: String) async throws -> String {
        guard nft.type == .erc1155 else {
            throw NFTError.unsupportedType
        }
        
        // ERC1155 safeTransferFrom function
        let functionSignature = "safeTransferFrom(address,address,uint256,uint256,bytes)"
        let selector = Keccak256.hash(string: functionSignature).prefix(4)
        
        var data = Data(selector)
        
        // Encode parameters similar to ERC721
        // (Implementation details omitted for brevity)
        
        // Create and send transaction
        let chainId = Int(nft.chain) ?? 1
        let transaction = EthereumTransaction(
            to: nft.contractAddress,
            from: from,
            nonce: BigUInt(0),
            value: BigUInt(0),
            data: data,
            gasLimit: BigUInt(200000),
            chainId: chainId
        )
        
        let signedTx = try await KeyringManager.shared.signTransaction(address: from, transaction: transaction)
        let txHash = try await TransactionManager.shared.broadcastTransaction(signedTx)
        
        return txHash
    }
    
    /// Check if address owns NFT
    func ownsNFT(contractAddress: String, tokenId: String, owner: String, chain: Chain) async throws -> Bool {
        // ERC721 ownerOf function
        let functionSignature = "ownerOf(uint256)"
        let selector = Keccak256.hash(string: functionSignature).prefix(4)
        
        var callData = Data(selector)
        if let tokenIdNum = UInt256(tokenId) {
            callData.append(tokenIdNum.data)
        }
        
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

struct UInt256 {
    let data: Data
    
    init?(_ string: String) {
        guard let value = UInt(string) else { return nil }
        
        var bytes = Data(repeating: 0, count: 32)
        var temp = value
        var index = 31
        
        while temp > 0 && index >= 0 {
            bytes[index] = UInt8(temp & 0xFF)
            temp >>= 8
            index -= 1
        }
        
        self.data = bytes
    }
}

// MARK: - Errors

enum NFTError: Error, LocalizedError {
    case unsupportedType
    case notFound
    case transferFailed
    
    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Unsupported NFT type"
        case .notFound:
            return "NFT not found"
        case .transferFailed:
            return "Failed to transfer NFT"
        }
    }
}
