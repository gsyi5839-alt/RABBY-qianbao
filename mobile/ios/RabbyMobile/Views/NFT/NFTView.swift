import SwiftUI
import BigInt

/// NFT View - Display and manage NFTs
struct NFTView: View {
    @StateObject private var nftManager = NFTManager.shared
    @State private var selectedCollection: NFTManager.NFTCollection?
    @State private var selectedNFT: NFTManager.NFT?
    @State private var showDetail = false
    
    var body: some View {
        NavigationView {
            Group {
                if nftManager.isLoading {
                    ProgressView(L("Loading NFTs..."))
                } else if nftManager.collections.isEmpty {
                    emptyState
                } else {
                    collectionsList
                }
            }
            .navigationTitle(L("NFTs"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedNFT) { nft in NFTDetailView(nft: nft) }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 48)).foregroundColor(.gray)
            Text(L("No NFTs found")).font(.headline).foregroundColor(.secondary)
            Text(L("Your NFTs will appear here")).font(.subheadline).foregroundColor(.gray)
        }
    }
    
    private var collectionsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(nftManager.collections) { collection in
                    collectionCard(collection: collection)
                }
            }.padding()
        }
    }
    
    private func collectionCard(collection: NFTManager.NFTCollection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(collection.name).font(.headline)
                Spacer()
                Text("\(collection.nftCount) items").font(.caption).foregroundColor(.secondary)
            }
            
            if let floor = collection.floorPrice {
                Text("Floor: \(floor)").font(.caption).foregroundColor(.secondary)
            }
            
            let nfts = nftManager.getNFTs(for: "", chain: collection.chain)
                .filter { $0.contractAddress.lowercased() == collection.contractAddress.lowercased() }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(nfts) { nft in
                    nftThumbnail(nft: nft)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func nftThumbnail(nft: NFTManager.NFT) -> some View {
        Button(action: { selectedNFT = nft }) {
            VStack {
                AsyncImage(url: URL(string: nft.image ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray4))
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }
                .frame(width: 100, height: 100).cornerRadius(8).clipped()
                
                Text(nft.name).font(.caption).lineLimit(1)
                if nft.type == .erc1155, let amount = nft.amount {
                    Text("x\(amount)").font(.caption2).foregroundColor(.secondary)
                }
            }
        }.buttonStyle(.plain)
    }
}

/// NFT Detail View
struct NFTDetailView: View {
    let nft: NFTManager.NFT
    @State private var showSendSheet = false
    @State private var recipientAddress = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // NFT Image
                    AsyncImage(url: URL(string: nft.image ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray4))
                            .frame(height: 300)
                            .overlay(ProgressView())
                    }
                    .frame(maxHeight: 350).cornerRadius(16).padding(.horizontal)
                    
                    // Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(nft.name).font(.title2).fontWeight(.bold)
                        if let collection = nft.collectionName {
                            Text(collection).font(.subheadline).foregroundColor(.secondary)
                        }
                        if let desc = nft.description { Text(desc).font(.body) }
                        
                        Divider()
                        
                        infoRow("Type", nft.type.rawValue)
                        infoRow("Token ID", "#\(nft.tokenId)")
                        infoRow("Contract", String(nft.contractAddress.prefix(10)) + "..." + String(nft.contractAddress.suffix(6)))
                        infoRow("Chain", nft.chain)
                        if let floor = nft.floorPrice { infoRow("Floor Price", floor) }
                    }.padding(.horizontal)
                    
                    // Send button
                    Button(action: { showSendSheet = true }) {
                        Text(L("Send NFT"))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                    }.padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(L("NFT Detail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button(L("Close")) { dismiss() } } }
        }
        .sheet(isPresented: $showSendSheet) {
            SendNFTView(nft: nft)
        }
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundColor(.secondary); Spacer(); Text(value).fontWeight(.medium) }
    }
}

/// Send NFT View
struct SendNFTView: View {
    let nft: NFTManager.NFT
    @State private var recipient = ""
    @State private var amount = "1"
    @State private var isSending = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss

    private var trimmedRecipient: String {
        recipient.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isAmountValid: Bool {
        guard nft.type == .erc1155 else { return true }
        guard let value = BigUInt(amount.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return value > 0
    }

    private var canSend: Bool {
        EthereumUtil.isValidAddress(trimmedRecipient) && isAmountValid && !isSending
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // NFT preview
                HStack {
                    AsyncImage(url: URL(string: nft.image ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { Color.gray }
                    .frame(width: 60, height: 60).cornerRadius(8)
                    
                    VStack(alignment: .leading) {
                        Text(nft.name).fontWeight(.semibold)
                        Text(nft.type.rawValue).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }.padding(.horizontal)
                
                // Recipient
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("To Address")).font(.caption).foregroundColor(.secondary)
                    TextField(L("0x..."), text: $recipient)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding()
                        .background(Color(.systemGray6)).cornerRadius(8)
                }.padding(.horizontal)
                
                // Amount for ERC1155
                if nft.type == .erc1155 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Amount")).font(.caption).foregroundColor(.secondary)
                        TextField(L("1"), text: $amount).keyboardType(.numberPad).padding()
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }.padding(.horizontal)
                }
                
                if let error = errorMessage {
                    Text(error).font(.caption).foregroundColor(.red).padding(.horizontal)
                }
                
                Spacer()
                
                Button(action: sendNFT) {
                    HStack {
                        if isSending { ProgressView().tint(.white) }
                        Text(isSending ? "Sending..." : "Send")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(canSend ? Color.blue : Color.gray)
                    .foregroundColor(.white).cornerRadius(12)
                }
                .disabled(!canSend)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle(L("Send NFT"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button(L("Cancel")) { dismiss() } } }
        }
    }
    
    private func sendNFT() {
        guard let address = PreferenceManager.shared.currentAccount?.address else { return }
        guard EthereumUtil.isValidAddress(trimmedRecipient) else {
            errorMessage = "Invalid recipient address"
            return
        }
        if nft.type == .erc1155 && !isAmountValid {
            errorMessage = "Invalid amount"
            return
        }

        isSending = true; errorMessage = nil
        Task {
            do {
                if nft.type == .erc721 {
                    _ = try await NFTManager.shared.sendNFT(nft, to: trimmedRecipient, from: address)
                } else {
                    _ = try await NFTManager.shared.sendERC1155(
                        nft,
                        to: trimmedRecipient,
                        from: address,
                        amount: amount.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                dismiss()
            } catch { errorMessage = error.localizedDescription }
            isSending = false
        }
    }
}
