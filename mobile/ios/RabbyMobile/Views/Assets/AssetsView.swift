import SwiftUI
import CoreImage.CIFilterBuiltins

/// Assets view showing wallet balance and tokens
struct AssetsView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var tokenManager = TokenManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @StateObject private var prefManager = PreferenceManager.shared
    @StateObject private var txManager = TransactionManager.shared
    
    @State private var selectedAddress: String = ""
    @State private var showSendSheet = false
    @State private var showReceiveSheet = false
    @State private var showSwitchAccount = false
    @State private var showSwitchChain = false
    @State private var showImportOptions = false
    @State private var tokenSearch = ""
    @State private var copiedToast = false
    @State private var showAddCustomToken = false
    @State private var showBlockedTokens = false
    @State private var assetTab: AssetTab = .tokens
    
    enum AssetTab: String, CaseIterable {
        case tokens = "Tokens"
        case nfts = "NFTs"
    }
    
    /// Computed total USD balance
    private var totalUSD: Double {
        let tokens = getTokens()
        var total: Double = 0
        for token in tokens {
            if let bal = tokenManager.getCachedBalance(tokenId: token.id) {
                let amount = Double(bal.balanceFormatted) ?? 0
                total += amount * token.price
            }
        }
        return total
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    accountHeader
                    
                    // Gas price bar
                    GasPriceBarView()
                        .padding(.horizontal)
                        .padding(.top, 4)
                    
                    totalBalanceCard
                    
                    // Chain balance distribution
                    if !selectedAddress.isEmpty {
                        ChainBalanceView(address: selectedAddress)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    
                    actionButtons
                    
                    // Asset tab switcher
                    assetTabSwitcher
                    
                    // Content based on tab
                    switch assetTab {
                    case .tokens:
                        tokenSearchBar
                        tokenListSection
                        
                        // DeFi Positions
                        if !selectedAddress.isEmpty {
                            ProtocolPositionView(address: selectedAddress)
                                .padding(.top, 8)
                        }
                    case .nfts:
                        NFTGalleryView(address: selectedAddress)
                    }
                }
            }
            .refreshable {
                await refreshBalancesAsync()
            }
            .navigationTitle(L("Assets"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSwitchAccount = true }) {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Switch account")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Pending transactions badge
                        if txManager.pendingCount > 0 {
                            NavigationLink(destination: TransactionHistoryView()) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text("\(txManager.pendingCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(3)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        
                        Button(action: { showImportOptions = true }) {
                            Image(systemName: "plus.circle")
                        }
                        .accessibilityLabel("Import or add wallet")
                        
                        Button(action: { showSwitchChain = true }) {
                            Image(systemName: "link.circle")
                        }
                        .accessibilityLabel("Switch chain")
                    }
                }
            }
            .sheet(isPresented: $showSendSheet) { SendTokenView() }
            .sheet(isPresented: $showReceiveSheet) { ReceiveView(address: selectedAddress) }
            .sheet(isPresented: $showSwitchAccount) { SwitchAccountPopup(isPresented: $showSwitchAccount) }
            .sheet(isPresented: $showSwitchChain) { SwitchChainPopup(isPresented: $showSwitchChain) }
            .sheet(isPresented: $showImportOptions) { ImportOptionsView() }
            .sheet(isPresented: $showAddCustomToken) { AddCustomTokenView() }
            .overlay(alignment: .bottom) {
                if copiedToast {
                    Text(L("Address copied!"))
                        .font(.subheadline).fontWeight(.medium)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear { loadData() }
    }
    
    // MARK: - Account Header
    private var accountHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                let alias = prefManager.getAlias(address: selectedAddress)
                Text(alias ?? EthereumUtil.formatAddress(selectedAddress))
                    .font(.headline)
                    .accessibilityLabel("Current account: \(alias ?? selectedAddress)")
                
                if let chain = chainManager.selectedChain {
                    Text(chain.name)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Quick copy address
            Button(action: copyAddress) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .accessibilityLabel("Copy address")
            
            // Chain selector pill
            if let chain = chainManager.selectedChain {
                Menu {
                    ForEach(chainManager.mainnetChains, id: \.id) { c in
                        Button(action: { chainManager.selectChain(c); loadData() }) {
                            Label(c.name, systemImage: chainManager.selectedChain?.id == c.id ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(chain.symbol)
                            .font(.caption).fontWeight(.semibold)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                }
                .accessibilityLabel("Current chain: \(chain.name). Tap to switch.")
            }
        }
        .padding()
    }
    
    // MARK: - Total Balance Card
    private var totalBalanceCard: some View {
        VStack(spacing: 8) {
            Text(L("Total Balance"))
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(formatCurrency(totalUSD))
                .font(.system(size: 36, weight: .bold))
                .accessibilityLabel("Total balance \(formatCurrency(totalUSD))")
            
            // Balance curve
            if !selectedAddress.isEmpty {
                BalanceCurveView(address: selectedAddress)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 16) {
            ActionButton(icon: "arrow.up.circle.fill", title: "Send", color: .blue) {
                hapticLight()
                showSendSheet = true
            }
            ActionButton(icon: "arrow.down.circle.fill", title: "Receive", color: .green) {
                hapticLight()
                showReceiveSheet = true
            }
            ActionButton(icon: "arrow.2.squarepath", title: "Swap", color: .orange) {
                hapticLight()
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    // MARK: - Asset Tab Switcher
    private var assetTabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(AssetTab.allCases, id: \.self) { tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { assetTab = tab } }) {
                    Text(tab.rawValue)
                        .font(.subheadline).fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(assetTab == tab ? Color.blue : Color.clear)
                        .foregroundColor(assetTab == tab ? .white : .secondary)
                        .cornerRadius(8)
                }
            }
        }
        .padding(3)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    // MARK: - Token Search
    private var tokenSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField(L("Search tokens"), text: $tokenSearch)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
            
            // LP Token toggle
            Button(action: { tokenManager.showLPTokens.toggle() }) {
                Text(L("LP"))
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(tokenManager.showLPTokens ? Color.blue : Color(.systemGray5))
                    .foregroundColor(tokenManager.showLPTokens ? .white : .secondary)
                    .cornerRadius(4)
            }
            
            // Add custom token
            Button(action: { showAddCustomToken = true }) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    // MARK: - Token List
    private var tokenListSection: some View {
        let tokens = filteredTokens()
        let visibleTokens = tokens.filter { !tokenManager.isBlocked(tokenId: $0.id) }
        let blockedCount = tokens.filter { tokenManager.isBlocked(tokenId: $0.id) }.count
        
        return LazyVStack(spacing: 0) {
            if visibleTokens.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.gray)
                    Text(L("No tokens found")).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(visibleTokens, id: \.id) { token in
                    TokenRow(token: token)
                        .padding(.horizontal)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                tokenManager.blockToken(id: token.id)
                            } label: {
                                Label(L("Block"), systemImage: "eye.slash")
                            }
                            .tint(.orange)
                        }
                    Divider().padding(.leading, 72)
                }
            }
            
            // Blocked tokens section
            if blockedCount > 0 {
                blockedTokensSection(count: blockedCount, tokens: tokens)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Blocked Tokens Section
    private func blockedTokensSection(count: Int, tokens: [TokenItem]) -> some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { showBlockedTokens.toggle() } }) {
                HStack {
                    Image(systemName: "eye.slash")
                        .font(.caption)
                    Text("\(count) blocked token\(count > 1 ? "s" : "")")
                        .font(.caption)
                    Spacer()
                    Image(systemName: showBlockedTokens ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            
            if showBlockedTokens {
                let blockedTokenList = tokens.filter { tokenManager.isBlocked(tokenId: $0.id) }
                ForEach(blockedTokenList, id: \.id) { token in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(token.symbol.prefix(1)))
                                    .font(.caption).foregroundColor(.gray)
                            )
                        
                        Text(token.symbol)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: { tokenManager.unblockToken(id: token.id) }) {
                            Text(L("Unblock"))
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Color(.systemGray6).opacity(0.5))
    }
    
    // MARK: - Helpers
    
    private func loadData() {
        guard let currentAccount = keyringManager.currentAccount else { return }
        selectedAddress = currentAccount.address
        if let chain = chainManager.selectedChain {
            Task { try? await tokenManager.loadTokens(address: currentAccount.address, chain: chain) }
        }
    }
    
    private func refreshBalancesAsync() async {
        guard let currentAccount = keyringManager.currentAccount else { return }
        await tokenManager.refreshBalances(address: currentAccount.address)
        hapticSuccess()
    }
    
    private func getTokens() -> [TokenItem] {
        guard let chain = chainManager.selectedChain else { return [] }
        let key = "\(selectedAddress.lowercased())_\(chain.id)"
        return tokenManager.tokens[key] ?? []
    }
    
    private func filteredTokens() -> [TokenItem] {
        let tokens = getTokens()
        guard !tokenSearch.isEmpty else { return tokens }
        let q = tokenSearch.lowercased()
        return tokens.filter { $0.symbol.lowercased().contains(q) || $0.name.lowercased().contains(q) }
    }
    
    private func copyAddress() {
        UIPasteboard.general.string = selectedAddress
        hapticSuccess()
        withAnimation(.spring()) { copiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedToast = false }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = prefManager.currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    private func hapticLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    private func hapticSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .accessibilityLabel(title)
    }
}

struct TokenRow: View {
    let token: TokenItem
    @StateObject private var tokenManager = TokenManager.shared
    @State private var showDetail = false
    
    var body: some View {
        Button(action: { showDetail = true }) {
            HStack(spacing: 12) {
                // Token icon (ErikThiart/cryptocurrency-icons fallback)
                CryptoIconView(symbol: token.symbol, logoURL: token.logoURL, size: 40)
                
                // Token info
                VStack(alignment: .leading, spacing: 2) {
                    Text(token.symbol).font(.headline)
                    HStack(spacing: 4) {
                        Text(token.name).font(.caption).foregroundColor(.gray)
                        if let change = token.priceChange24h {
                            priceChangeBadge(change)
                        }
                    }
                }
                
                Spacer()
                
                // Balance + USD value
                VStack(alignment: .trailing, spacing: 2) {
                    if let balance = tokenManager.getCachedBalance(tokenId: token.id) {
                        Text(balance.balanceFormatted)
                            .font(.subheadline).fontWeight(.medium)
                        
                        let usdValue = (Double(balance.balanceFormatted) ?? 0) * token.price
                        if usdValue > 0 {
                            Text("$\(String(format: "%.2f", usdValue))")
                                .font(.caption).foregroundColor(.gray)
                        }
                    } else {
                        ProgressView().scaleEffect(0.7)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(token.symbol), \(tokenManager.getCachedBalance(tokenId: token.id)?.balanceFormatted ?? "loading")")
        .sheet(isPresented: $showDetail) {
            TokenDetailView(token: token)
        }
    }
    

    
    private func priceChangeBadge(_ change: Double) -> some View {
        let isPositive = change >= 0
        return HStack(spacing: 1) {
            Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 6))
            Text(String(format: "%.1f%%", abs(change * 100)))
                .font(.system(size: 9))
        }
        .foregroundColor(isPositive ? .green : .red)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background((isPositive ? Color.green : Color.red).opacity(0.1))
        .cornerRadius(4)
    }
}

/// Receive View with real CoreImage QR code generation
struct ReceiveView: View {
    let address: String
    @Environment(\.dismiss) var dismiss
    @State private var copiedToast = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Real QR Code using CoreImage
                if let qrImage = generateQRCode(from: address) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        .accessibilityLabel("QR code for your address")
                }
                
                // Address
                VStack(spacing: 8) {
                    Text(L("Your Address")).font(.headline)
                    Text(address)
                        .font(.system(.caption, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
                .padding(.horizontal)
                
                // Copy button
                Button(action: copyAddress) {
                    HStack {
                        Image(systemName: copiedToast ? "checkmark" : "doc.on.doc")
                        Text(copiedToast ? "Copied!" : "Copy Address")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(copiedToast ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .animation(.easeInOut, value: copiedToast)
                }
                .padding(.horizontal)
                .accessibilityLabel("Copy address to clipboard")
                
                Spacer()
            }
            .navigationTitle(L("Receive"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
        }
    }
    
    private func copyAddress() {
        UIPasteboard.general.string = address
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { copiedToast = true }
        // Auto-clear clipboard after 60 seconds for security
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if UIPasteboard.general.string == address {
                UIPasteboard.general.string = ""
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedToast = false }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scale = 250.0 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Preview

struct AssetsView_Previews: PreviewProvider {
    static var previews: some View {
        AssetsView()
    }
}
