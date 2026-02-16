import SwiftUI

/// Security / Token Approvals management view
/// Corresponds to: extension DashboardPanel approval badge + approval management
/// Uses /v1/user/approval_status for summary and /v1/user/token_authorized_list per chain for details
struct ApprovalsView: View {
    let address: String
    
    @State private var approvals: [OpenAPIService.TokenApproval] = []
    @State private var nftApprovals: [OpenAPIService.NFTApproval] = []
    @State private var isLoading = true
    @State private var isLoadingDetails = false
    @State private var error: String?
    @State private var dangerSummary: OpenAPIService.ApprovalStatus?
    @Environment(\.dismiss) private var dismiss
    
    private var riskyApprovals: [OpenAPIService.TokenApproval] {
        approvals.filter { $0.isRisky }
    }
    
    private var safeApprovals: [OpenAPIService.TokenApproval] {
        approvals.filter { !$0.isRisky }
    }
    
    private var riskyNFTApprovals: [OpenAPIService.NFTApproval] {
        nftApprovals.filter { $0.isRisky }
    }
    
    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                            Text(L("Loading approvals..."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            } else if let error = error {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(L("Retry")) {
                            Task { await loadApprovals() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }
            } else if approvals.isEmpty && nftApprovals.isEmpty && !isLoadingDetails {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "shield.checkmark")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text(L("No token approvals found"))
                            .font(.headline)
                        Text(L("Your wallet has no active token approvals"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .listRowBackground(Color.clear)
                }
            } else {
                // Summary section
                if let summary = dangerSummary, summary.totalDangerCount > 0 {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("Risk Detected"))
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text("\(summary.token_approval_danger_cnt ?? 0) token, \(summary.nft_approval_danger_cnt ?? 0) NFT risky approvals")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Risky token approvals
                if !riskyApprovals.isEmpty {
                    Section {
                        ForEach(riskyApprovals, id: \.uniqueId) { approval in
                            tokenApprovalRow(approval)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(.red)
                            Text(L("Risky Token Approvals"))
                                .foregroundColor(.red)
                            Spacer()
                            Text("\(riskyApprovals.count)")
                                .font(.caption).fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Risky NFT approvals
                if !riskyNFTApprovals.isEmpty {
                    Section {
                        ForEach(riskyNFTApprovals, id: \.uniqueId) { approval in
                            nftApprovalRow(approval)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(.orange)
                            Text(L("Risky NFT Approvals"))
                                .foregroundColor(.orange)
                            Spacer()
                            Text("\(riskyNFTApprovals.count)")
                                .font(.caption).fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Safe approvals
                if !safeApprovals.isEmpty {
                    Section {
                        ForEach(safeApprovals, id: \.uniqueId) { approval in
                            tokenApprovalRow(approval)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "shield.checkmark")
                                .foregroundColor(.green)
                            Text(L("Other Approvals"))
                            Spacer()
                            Text("\(safeApprovals.count)")
                                .font(.caption).fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Show loading indicator while fetching per-chain details
                if isLoadingDetails {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text(L("Loading details..."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .navigationTitle(L("Security"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadApprovals() }
    }
    
    private func tokenApprovalRow(_ approval: OpenAPIService.TokenApproval) -> some View {
        HStack(spacing: 12) {
            // Token icon
            if let logoUrl = approval.token_logo_url, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Circle().fill(Color(.systemGray5))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                // Risk indicator
                Circle()
                    .fill(approval.isRisky ? Color.red : Color.green)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: approval.isRisky ? "exclamationmark" : "checkmark")
                            .font(.caption2)
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Token symbol + spender
                HStack(spacing: 4) {
                    if let symbol = approval.token_symbol {
                        Text(symbol)
                            .font(.subheadline).fontWeight(.medium)
                    }
                    Text("→")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(EthereumUtil.formatAddress(approval.spender ?? "Unknown"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Chain
                if let chain = approval.chain {
                    Text(chain.uppercased())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Risk level badge
                if let level = approval.risk_level {
                    Text(level.capitalized)
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundColor(approval.isRisky ? .red : .green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((approval.isRisky ? Color.red : Color.green).opacity(0.1))
                        .cornerRadius(4)
                }
                
                // Risk alert
                if let alert = approval.risk_alert, !alert.isEmpty {
                    Text(alert)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func nftApprovalRow(_ approval: OpenAPIService.NFTApproval) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(approval.isRisky ? Color.orange : Color.green)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "photo.artframe")
                        .font(.caption2)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(approval.nft_name ?? approval.contract_name ?? "NFT")
                    .font(.subheadline).fontWeight(.medium)
                
                Text(EthereumUtil.formatAddress(approval.spender ?? "Unknown"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let chain = approval.chain {
                    Text(chain.uppercased())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let level = approval.risk_level {
                Text(level.capitalized)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundColor(approval.isRisky ? .orange : .green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((approval.isRisky ? Color.orange : Color.green).opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    /// Smart loading with automatic retry for rate limits.
    /// Phase 1: Show summary from approval_status (single call with retry)
    /// Phase 2: Load per-chain details one-by-one in background
    private func loadApprovals() async {
        isLoading = true
        error = nil
        
        // ── Phase 1: Get danger summary with retry ──
        // Wait a bit on first load to let other API calls from AssetsView settle
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s initial delay
        
        var summaryLoaded = false
        for attempt in 0..<5 {
            do {
                let statusList = try await OpenAPIService.shared.getApprovalStatus(address: address)
                await MainActor.run {
                    self.dangerSummary = statusList.first
                    self.isLoading = false
                    self.isLoadingDetails = true
                }
                summaryLoaded = true
                break
            } catch let err {
                let isRateLimit = err.localizedDescription.contains("429")
                if isRateLimit && attempt < 4 {
                    let waitSecs = Double(attempt + 1) * 3.0 // 3s, 6s, 9s, 12s
                    NSLog("[ApprovalsView] Rate limited on approval_status, waiting %.0fs (attempt %d)...", waitSecs, attempt + 1)
                    try? await Task.sleep(nanoseconds: UInt64(waitSecs * 1_000_000_000))
                    continue
                }
                // Not a rate limit error, or exhausted retries
                await MainActor.run {
                    if isRateLimit {
                        // Show friendly rate limit message instead of raw error
                        self.error = nil
                        self.isLoading = false
                        // Just show "no approvals" state - better than error
                    } else {
                        self.error = err.localizedDescription
                        self.isLoading = false
                    }
                }
                return
            }
        }
        
        guard summaryLoaded else { return }
        
        // Pause before Phase 2
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
        
        // ── Phase 2: Get per-chain details ──
        var chainIds: [String] = []
        do {
            let usedChains = try await OpenAPIService.shared.getUsedChainList(address: address)
            chainIds = usedChains.map { $0.id }
            NSLog("[ApprovalsView] User has activity on %d chains", chainIds.count)
        } catch {
            NSLog("[ApprovalsView] Failed to get used chain list: %@, skipping details", "\(error)")
            await MainActor.run { self.isLoadingDetails = false }
            return
        }
        
        // Fetch per chain, ONE at a time sequentially with pauses
        var allTokenApprovals: [OpenAPIService.TokenApproval] = []
        var allNFTApprovals: [OpenAPIService.NFTApproval] = []
        
        for (index, cid) in chainIds.enumerated() {
            // Pause between chains (longer than throttle to be safe)
            if index > 0 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms between chains
            }
            
            // Token approvals
            do {
                let tokens = try await OpenAPIService.shared.getTokenAuthorizedList(
                    address: address, chainId: cid
                )
                if !tokens.isEmpty {
                    allTokenApprovals.append(contentsOf: tokens)
                    await MainActor.run { self.approvals = allTokenApprovals }
                }
            } catch {
                NSLog("[ApprovalsView] Token approval failed for %@: %@", cid, "\(error)")
            }
            
            // NFT approvals
            do {
                let nfts = try await OpenAPIService.shared.getNFTAuthorizedList(
                    address: address, chainId: cid
                )
                if !nfts.isEmpty {
                    allNFTApprovals.append(contentsOf: nfts)
                    await MainActor.run { self.nftApprovals = allNFTApprovals }
                }
            } catch {
                NSLog("[ApprovalsView] NFT approval failed for %@: %@", cid, "\(error)")
            }
        }
        
        await MainActor.run {
            self.approvals = allTokenApprovals
            self.nftApprovals = allNFTApprovals
            self.isLoadingDetails = false
        }
    }
}

// MARK: - Identifiable helpers

extension OpenAPIService.TokenApproval {
    var uniqueId: String {
        "\(spender ?? "")-\(token_id ?? "")-\(chain ?? "")"
    }
}

extension OpenAPIService.NFTApproval {
    var uniqueId: String {
        "\(spender ?? "")-\(id ?? "")-\(chain ?? "")"
    }
}
