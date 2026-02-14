import SwiftUI

/// NFT Gallery View with grid layout for Assets tab
/// Corresponds to: src/ui/views/NFTView/ + Dashboard/components/NFT/
struct NFTGalleryView: View {
    let address: String
    
    @State private var nfts: [OpenAPIService.NFTInfo] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedNFT: OpenAPIService.NFTInfo?
    
    private var filteredNFTs: [OpenAPIService.NFTInfo] {
        guard !searchText.isEmpty else { return nfts }
        let q = searchText.lowercased()
        return nfts.filter {
            ($0.name?.lowercased().contains(q) ?? false) ||
            $0.contract_id.lowercased().contains(q)
        }
    }
    
    // Group NFTs by collection
    private var collections: [NFTCollectionGroup] {
        let grouped = Dictionary(grouping: filteredNFTs) { $0.collection_id ?? $0.contract_id }
        return grouped.map { (key, items) in
            NFTCollectionGroup(
                id: key,
                name: items.first?.name ?? "Unknown Collection",
                items: items,
                thumbnail: items.first?.thumbnail_url ?? items.first?.content
            )
        }
        .sorted { $0.items.count > $1.items.count }
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField(L("Search NFTs"), text: $searchText)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(L("Loading NFTs..."))
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else if filteredNFTs.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text(L("No NFTs Found"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(L("NFTs you own will appear here"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // NFT Grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredNFTs, id: \.id) { nft in
                        nftCard(nft)
                    }
                }
                .padding(.horizontal)
            }
        }
        .task { await loadNFTs() }
    }
    
    // MARK: - NFT Card
    
    private func nftCard(_ nft: OpenAPIService.NFTInfo) -> some View {
        Button(action: { selectedNFT = nft }) {
            VStack(alignment: .leading, spacing: 8) {
                // NFT Image
                if let imageUrl = nft.thumbnail_url ?? nft.content,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                        case .failure:
                            nftPlaceholder
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        @unknown default:
                            nftPlaceholder
                        }
                    }
                } else {
                    nftPlaceholder
                }
                
                // NFT Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(nft.name ?? "Unnamed NFT")
                        .font(.caption).fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("#\(nft.inner_id)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Chain badge
                    Text(nft.chain.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(3)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(item: $selectedNFT) { nft in
            NFTDetailSheet(nft: nft)
        }
    }
    
    private var nftPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            )
    }
    
    // MARK: - Data Loading
    
    private func loadNFTs() async {
        isLoading = true
        do {
            nfts = try await OpenAPIService.shared.getNFTList(address: address)
        } catch {
            nfts = []
        }
        isLoading = false
    }
}

// MARK: - Supporting Types

struct NFTCollectionGroup: Identifiable {
    let id: String
    let name: String
    let items: [OpenAPIService.NFTInfo]
    let thumbnail: String?
}

extension OpenAPIService.NFTInfo: Identifiable {
}

// MARK: - NFT Detail Sheet

struct NFTDetailSheet: View {
    let nft: OpenAPIService.NFTInfo
    @State private var detailInfo: OpenAPIService.NFTDetailInfo?
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // NFT Image
                    if let imageUrl = nft.thumbnail_url ?? nft.content,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                        } placeholder: {
                            ProgressView()
                                .frame(height: 300)
                        }
                    }
                    
                    // Name + Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(nft.name ?? "Unnamed NFT")
                            .font(.title2).fontWeight(.bold)
                        
                        Text("Token ID: #\(nft.inner_id)")
                            .font(.caption).foregroundColor(.secondary)
                        
                        if let desc = nft.description ?? detailInfo?.description {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Collection info
                    if let collection = detailInfo?.collection {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Collection"))
                                .font(.headline)
                            
                            HStack(spacing: 10) {
                                if let logoUrl = collection.logo_url, let url = URL(string: logoUrl) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().frame(width: 36, height: 36).clipShape(Circle())
                                    } placeholder: {
                                        Circle().fill(Color.blue.opacity(0.15)).frame(width: 36, height: 36)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(collection.name)
                                        .font(.subheadline).fontWeight(.medium)
                                    if let floor = collection.floor_price {
                                        Text("Floor: \(String(format: "%.4f", floor)) ETH")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Attributes / Traits
                    if let attributes = detailInfo?.attributes, !attributes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Attributes"))
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(attributes, id: \.trait_type) { attr in
                                    VStack(spacing: 4) {
                                        Text(attr.trait_type)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(attr.value)
                                            .font(.caption).fontWeight(.medium)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Contract info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Contract"))
                            .font(.headline)
                        Text(nft.contract_id)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle(L("NFT Detail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
            .task { await loadDetail() }
        }
    }
    
    private func loadDetail() async {
        do {
            detailInfo = try await OpenAPIService.shared.getNFTDetail(
                chainId: nft.chain,
                contractId: nft.contract_id,
                tokenId: nft.inner_id
            )
        } catch {
            // Silent fail, basic info is already shown
        }
        isLoading = false
    }
}
