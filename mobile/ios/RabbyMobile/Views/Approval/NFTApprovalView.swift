import SwiftUI
import BigInt

/// NFT Approval Management - view/revoke NFT approvals by contract
/// Corresponds to: src/ui/views/Approval/ (NFT section)
struct NFTApprovalView: View {
    @StateObject private var viewModel = NFTApprovalViewModel()
    @State private var searchText = ""
    @State private var isSelectMode = false
    @State private var selectedIds: Set<String> = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(L("Search by contract or collection"), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView(L("Loading approvals..."))
                    Spacer()
                } else if filteredApprovals.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text(L("No NFT Approvals"))
                            .font(.headline)
                        Text(L("You have no active NFT approvals"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredApprovals) { approval in
                            NFTApprovalRow(
                                approval: approval,
                                isSelectMode: isSelectMode,
                                isSelected: selectedIds.contains(approval.id),
                                onToggle: { toggleSelection(approval.id) },
                                onRevoke: { revokeApproval(approval) }
                            )
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.loadApprovals() }
                }

                // Batch revoke bar
                if isSelectMode && !selectedIds.isEmpty {
                    batchRevokeBar
                }
            }
            .navigationTitle(L("NFT Approvals"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSelectMode ? "Done" : "Select") {
                        isSelectMode.toggle()
                        if !isSelectMode { selectedIds.removeAll() }
                    }
                }
            }
        }
        .task { await viewModel.loadApprovals() }
    }

    private var filteredApprovals: [NFTApprovalItem] {
        if searchText.isEmpty { return viewModel.approvals }
        return viewModel.approvals.filter {
            $0.spenderName.localizedCaseInsensitiveContains(searchText) ||
            $0.spenderAddress.localizedCaseInsensitiveContains(searchText) ||
            $0.collectionName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var batchRevokeBar: some View {
        HStack {
            Text("\(selectedIds.count) selected")
                .font(.subheadline)
            Spacer()
            Button(action: { batchRevoke() }) {
                Text(L("Revoke Selected"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground).shadow(radius: 2))
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) { selectedIds.remove(id) }
        else { selectedIds.insert(id) }
    }

    private func revokeApproval(_ approval: NFTApprovalItem) {
        Task { await viewModel.revokeApproval(approval) }
    }

    private func batchRevoke() {
        let items = viewModel.approvals.filter { selectedIds.contains($0.id) }
        Task {
            for item in items {
                await viewModel.revokeApproval(item)
            }
            selectedIds.removeAll()
            isSelectMode = false
        }
    }
}

// MARK: - Approval Row

struct NFTApprovalRow: View {
    let approval: NFTApprovalItem
    let isSelectMode: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if isSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .onTapGesture { onToggle() }
            }

            // Risk indicator
            Circle()
                .fill(approval.riskColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(approval.spenderName.isEmpty ? EthereumUtil.truncateAddress(approval.spenderAddress) : approval.spenderName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(approval.collectionName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(approval.approvedCount) NFTs approved")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isSelectMode {
                Button(L("Revoke")) { onRevoke() }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
class NFTApprovalViewModel: ObservableObject {
    @Published var approvals: [NFTApprovalItem] = []
    @Published var isLoading = false

    func loadApprovals() async {
        isLoading = true
        defer { isLoading = false }

        // Fetch NFT approvals from API
        do {
            let address = KeyringManager.shared.currentAccount?.address ?? ""
            guard !address.isEmpty else { return }

            let items: [NFTApprovalItem] = try await OpenAPIService.shared.get(
                "/v1/user/nft_approval_list",
                params: ["user_addr": address]
            )
            approvals = items
        } catch {
            print("Failed to load NFT approvals: \(error)")
        }
    }

    func revokeApproval(_ approval: NFTApprovalItem) async {
        // Build revoke transaction
        let calldata: Data
        if approval.isApprovalForAll {
            // setApprovalForAll(operator, false) - selector: 0xa22cb465
            calldata = buildSetApprovalForAll(operator: approval.spenderAddress, approved: false)
        } else {
            // approve(address(0), tokenId) - selector: 0x095ea7b3
            calldata = buildApprove(to: "0x0000000000000000000000000000000000000000", tokenId: approval.tokenId ?? "0")
        }

        do {
            let fromAddress = KeyringManager.shared.currentAccount?.address ?? ""
            let chain = ChainManager.shared.selectedChain ?? Chain.ethereum
            let tx = try await TransactionManager.shared.buildTransaction(
                from: fromAddress,
                to: approval.contractAddress,
                value: "0x0",
                data: "0x" + calldata.hexString,
                chain: chain
            )
            let _ = try await TransactionManager.shared.sendTransaction(tx)
            // Remove from list on success
            approvals.removeAll { $0.id == approval.id }
        } catch {
            print("Failed to revoke: \(error)")
        }
    }

    private func buildSetApprovalForAll(operator addr: String, approved: Bool) -> Data {
        let selector = Data([0xa2, 0x2c, 0xb4, 0x65])
        let operatorPadded = EthereumUtil.padAddress(addr)
        let approvedPadded = Data(repeating: 0, count: 31) + Data([approved ? 1 : 0])
        return selector + operatorPadded + approvedPadded
    }

    private func buildApprove(to address: String, tokenId: String) -> Data {
        let selector = Data([0x09, 0x5e, 0xa7, 0xb3])
        let addrPadded = EthereumUtil.padAddress(address)
        let tokenIdBigInt = BigUInt(tokenId) ?? BigUInt(0)
        let tokenIdPadded = tokenIdBigInt.toPaddedData(length: 32)
        return selector + addrPadded + tokenIdPadded
    }
}

// MARK: - Models

struct NFTApprovalItem: Identifiable, Codable {
    var id: String { "\(contractAddress)_\(spenderAddress)_\(tokenId ?? "all")" }
    let contractAddress: String
    let spenderAddress: String
    let spenderName: String
    let collectionName: String
    let approvedCount: Int
    let isApprovalForAll: Bool
    let tokenId: String?
    let riskLevel: String // "safe", "warning", "danger"

    var riskColor: Color {
        switch riskLevel {
        case "danger": return .red
        case "warning": return .orange
        default: return .green
        }
    }

    enum CodingKeys: String, CodingKey {
        case contractAddress = "contract_address"
        case spenderAddress = "spender_address"
        case spenderName = "spender_name"
        case collectionName = "collection_name"
        case approvedCount = "approved_count"
        case isApprovalForAll = "is_approval_for_all"
        case tokenId = "token_id"
        case riskLevel = "risk_level"
    }
}

private extension Data {
    func padLeft(toLength length: Int) -> Data {
        if count >= length { return self }
        return Data(repeating: 0, count: length - count) + self
    }
}
