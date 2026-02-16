import SwiftUI
import CoreImage.CIFilterBuiltins
import Photos
import Combine

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
    @State private var showSwapSheet = false
    @State private var showBridgeSheet = false
    @State private var showSwitchAccount = false
    @State private var showSwitchChain = false
    @State private var showImportOptions = false
    @State private var tokenSearch = ""
    @State private var copiedToast = false
    @State private var showAddCustomToken = false
    @State private var showBlockedTokens = false
    @State private var showLowValueTokens = false
    @State private var assetTab: AssetTab = .tokens
    @State private var balanceHidden = UserDefaults.standard.bool(forKey: "rabby_balance_hidden")
    @State private var tokenSortOption: TokenSortOption = .value
    @State private var activeWCSessions: Int = 0
    @State private var approvalRiskCount: Int = 0
    @State private var offlineChains: [String] = []
    @State private var showOfflineChainBanner = true
    
    enum AssetTab: String, CaseIterable {
        case tokens = "Tokens"
        case nfts = "NFTs"
    }
    
    enum TokenSortOption: String, CaseIterable {
        case value = "By Value"
        case name = "By Name"
        case change = "By 24h Change"
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
                    
                    // Offline chain notification banner
                    if !offlineChains.isEmpty && showOfflineChainBanner {
                        offlineChainBanner
                    }
                    
                    // Active WalletConnect sessions banner
                    if activeWCSessions > 0 {
                        dappConnectionBanner
                    }
                    
                    // Gas price bar
                    GasPriceBarView()
                        .padding(.horizontal)
                        .padding(.top, 12)
                    
                    totalBalanceCard
                        .padding(.top, 12)
                    
                    // Chain balance distribution
                    if !selectedAddress.isEmpty {
                        ChainBalanceView(address: selectedAddress)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    
                    actionGrid
                        .padding(.top, 4)
                    
                    // Asset tab switcher
                    assetTabSwitcher
                        .padding(.top, 4)
                    
                    // Content based on tab
                    switch assetTab {
                    case .tokens:
                        tokenSearchBar
                            .padding(.top, 4)
                        tokenListSection
                        
                        // DeFi Positions
                        if !selectedAddress.isEmpty {
                            ProtocolPositionView(address: selectedAddress)
                                .padding(.top, 8)
                        }
                    case .nfts:
                        NFTGalleryView(address: selectedAddress)
                            .padding(.top, 4)
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
                                    Text("\(min(txManager.pendingCount, 99))\(txManager.pendingCount > 99 ? "+" : "")")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(3)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        
                        // Approval risk badge
                        if approvalRiskCount > 0 {
                            NavigationLink(destination: ApprovalsView(address: selectedAddress)) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "shield.lefthalf.filled")
                                    Text("\(approvalRiskCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(3)
                                        .background(Color.orange)
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
            .sheet(isPresented: $showSwapSheet) { SwapView() }
            .sheet(isPresented: $showBridgeSheet) { BridgeView() }
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
        .onAppear { loadData(); loadExtraData() }
        .onChange(of: keyringManager.currentAccount?.address) { _ in
            loadData()
            loadExtraData()
        }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Total Balance Card
    private var totalBalanceCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(L("Total Balance"))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Balance hide/show toggle
                Button(action: toggleBalanceVisibility) {
                    Image(systemName: balanceHidden ? "eye.slash.fill" : "eye.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .accessibilityLabel(balanceHidden ? "Show balance" : "Hide balance")
            }
            
            if balanceHidden {
                Text("****")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.secondary)
            } else {
                Text(formatCurrency(totalUSD))
                    .font(.system(size: 36, weight: .bold))
                    .accessibilityLabel("Total balance \(formatCurrency(totalUSD))")
            }
            
            // Balance curve
            if !selectedAddress.isEmpty && !balanceHidden {
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
    
    // MARK: - Action Grid (Expandable)
    @State private var showAllActions = false
    
    private var actionGrid: some View {
        VStack(spacing: 10) {
            // Primary actions row
            HStack(spacing: 12) {
                ActionButton(icon: "arrow.up.circle.fill", title: L("Send"), color: .blue) {
                    hapticLight()
                    showSendSheet = true
                }
                ActionButton(icon: "arrow.down.circle.fill", title: L("Receive"), color: .green) {
                    hapticLight()
                    showReceiveSheet = true
                }
                ActionButton(icon: "arrow.2.squarepath", title: L("Swap"), color: .orange) {
                    hapticLight()
                    showSwapSheet = true
                }
                ActionButton(icon: "arrow.left.arrow.right.circle.fill", title: L("Bridge"), color: .purple) {
                    hapticLight()
                    showBridgeSheet = true
                }
            }
            
            // Expandable secondary actions
            if showAllActions {
                HStack(spacing: 12) {
                    NavigationLink(destination: TransactionHistoryView()) {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 24))
                                .foregroundColor(.indigo)
                            Text(L("History"))
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    NavigationLink(destination: ApprovalsView(address: selectedAddress)) {
                        VStack(spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                                if approvalRiskCount > 0 {
                                    Text("\(approvalRiskCount)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(2)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 4, y: -4)
                                }
                            }
                            Text(L("Security"))
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    ActionButton(icon: "fuelpump.fill", title: L("Gas"), color: .yellow) {
                        hapticLight()
                        // Gas account handled by GasPriceBarView
                    }
                    
                    NavigationLink(destination: SettingsView()) {
                        VStack(spacing: 8) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            Text(L("Settings"))
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            
            // Expand/Collapse button
            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showAllActions.toggle() } }) {
                HStack(spacing: 4) {
                    Text(showAllActions ? L("Less") : L("More"))
                        .font(.caption2).fontWeight(.medium)
                    Image(systemName: showAllActions ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.secondary)
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
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(assetTab == tab ? Color.blue : Color.clear)
                        .foregroundColor(assetTab == tab ? .white : .secondary)
                        .cornerRadius(10)
                }
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    // MARK: - Token Search
    private var tokenSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField(L("Search tokens"), text: $tokenSearch)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
            
            // Sort menu
            Menu {
                ForEach(TokenSortOption.allCases, id: \.self) { option in
                    Button(action: { tokenSortOption = option }) {
                        HStack {
                            Text(L(option.rawValue))
                            if tokenSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            .accessibilityLabel("Sort tokens")
            
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
    
    /// Low-value threshold: tokens < 1% of portfolio, capped at $1000
    private var lowValueThreshold: Double {
        min(totalUSD * 0.01, 1000)
    }
    
    private func tokenUSDValue(_ token: TokenItem) -> Double {
        guard let balance = tokenManager.getCachedBalance(tokenId: token.id) else { return 0 }
        return (Double(balance.balanceFormatted) ?? 0) * token.price
    }
    
    private func sortedTokens(_ tokens: [TokenItem]) -> [TokenItem] {
        switch tokenSortOption {
        case .value:
            return tokens.sorted { tokenUSDValue($0) > tokenUSDValue($1) }
        case .name:
            return tokens.sorted { $0.symbol.lowercased() < $1.symbol.lowercased() }
        case .change:
            return tokens.sorted { ($0.priceChange24h ?? 0) > ($1.priceChange24h ?? 0) }
        }
    }
    
    private var tokenListSection: some View {
        let allTokens = filteredTokens()
        let visibleTokens = allTokens.filter { !tokenManager.isBlocked(tokenId: $0.id) }
        let blockedCount = allTokens.filter { tokenManager.isBlocked(tokenId: $0.id) }.count
        
        // Split into high-value and low-value
        let threshold = lowValueThreshold
        let highValueTokens = sortedTokens(visibleTokens.filter { tokenUSDValue($0) >= threshold || threshold == 0 })
        let lowValueTokens = sortedTokens(visibleTokens.filter { tokenUSDValue($0) < threshold && threshold > 0 })
        let lowValueTotal = lowValueTokens.reduce(0.0) { $0 + tokenUSDValue($1) }
        
        return LazyVStack(spacing: 0) {
            if visibleTokens.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.gray)
                    Text(L("No tokens found")).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // High-value tokens
                ForEach(highValueTokens, id: \.id) { token in
                    TokenRow(token: token, showLPBadge: true)
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
                
                // Low-value tokens collapsible section
                if !lowValueTokens.isEmpty {
                    lowValueTokensSection(
                        tokens: lowValueTokens,
                        count: lowValueTokens.count,
                        totalValue: lowValueTotal
                    )
                }
            }
            
            // Blocked tokens section
            if blockedCount > 0 {
                blockedTokensSection(count: blockedCount, tokens: allTokens)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Low-Value Tokens Section
    private func lowValueTokensSection(tokens: [TokenItem], count: Int, totalValue: Double) -> some View {
        let lowValueLabel = LocalizationManager.shared.t("low value token")
        return VStack(spacing: 0) {
            Button(action: { withAnimation { showLowValueTokens.toggle() } }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(count) \(lowValueLabel)\(count > 1 ? "s" : "") (\(formatCurrency(totalValue)))")
                        .font(.caption)
                    Spacer()
                    Image(systemName: showLowValueTokens ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            
            if showLowValueTokens {
                ForEach(tokens, id: \.id) { token in
                    TokenRow(token: token, showLPBadge: true)
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
        }
        .background(Color(.systemGray6).opacity(0.3))
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
    
    // MARK: - Offline Chain Notification Banner
    private var offlineChainBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Chain Service Disruption"))
                    .font(.caption).fontWeight(.semibold)
                let chainNames = offlineChains.prefix(3).joined(separator: ", ")
                let suffix = offlineChains.count > 3 ? " +\(offlineChains.count - 3)" : ""
                Text("\(chainNames)\(suffix)")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { withAnimation { showOfflineChainBanner = false } }) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - DApp Connection Banner
    private var dappConnectionBanner: some View {
        let activeConnectionLabel = LocalizationManager.shared.t("active connection")
        return NavigationLink(destination: WalletConnectSessionsView()) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("\(activeWCSessions) \(activeConnectionLabel)\(activeWCSessions > 1 ? "s" : "")")
                    .font(.caption).fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.green.opacity(0.08))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    // MARK: - Helpers
    
    private func loadData() {
        guard let currentAccount = keyringManager.currentAccount else { return }
        selectedAddress = currentAccount.address
        if let chain = chainManager.selectedChain {
            Task {
                _ = try? await tokenManager.loadTokens(address: currentAccount.address, chain: chain)

                // Optional QA-only fake balances. Disabled by default.
                if tokenManager.isTestBalanceInjectionEnabled {
                    injectTestTokensIfNeeded(address: currentAccount.address)
                }
            }
        }
    }
    
    /// Inject test tokens for development/testing purposes.
    /// This allows testing Send/Swap/Bridge flows without real on-chain funds.
    /// TODO: Remove before production release.
    private func injectTestTokensIfNeeded(address: String) {
        let chains = chainManager.allChains
        
        // Inject USDT on Ethereum
        if let ethChain = chains.first(where: { $0.serverId == "eth" }) {
            tokenManager.injectTestToken(
                address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
                symbol: "USDT",
                name: "Tether USD",
                decimals: 6,
                logoURL: "https://static.debank.com/image/eth_token/logo_url/0xdac17f958d2ee523a2206206994597c13d831ec7/66eadee7b7bb16b75e02b570ab8d5c01.png",
                price: 1.0,
                balance: 10_000_000,
                chain: ethChain,
                ownerAddress: address
            )
            
            // Also inject some ETH
            tokenManager.injectTestToken(
                address: ethChain.nativeTokenAddress,
                symbol: "ETH",
                name: "Ethereum",
                decimals: 18,
                logoURL: "https://static.debank.com/image/chain/logo_url/eth/42ba589cd077e7bdd97db6480b0ff61d.png",
                price: 2083.0,
                balance: 5.5,
                chain: ethChain,
                ownerAddress: address,
                isNative: true
            )
        }
        
        // Inject USDT on BNB Chain
        if let bscChain = chains.first(where: { $0.serverId == "bsc" }) {
            tokenManager.injectTestToken(
                address: "0x55d398326f99059fF775485246999027B3197955",
                symbol: "USDT",
                name: "Tether USD",
                decimals: 18,
                logoURL: "https://static.debank.com/image/bsc_token/logo_url/0x55d398326f99059ff775485246999027b3197955/66eadee7b7bb16b75e02b570ab8d5c01.png",
                price: 1.0,
                balance: 10_000_000,
                chain: bscChain,
                ownerAddress: address
            )
            
            // Also inject some BNB
            tokenManager.injectTestToken(
                address: bscChain.nativeTokenAddress,
                symbol: "BNB",
                name: "BNB",
                decimals: 18,
                logoURL: "https://static.debank.com/image/chain/logo_url/bsc/bc73fa84b7fc5337905e527dadcbc854.png",
                price: 631.0,
                balance: 10.0,
                chain: bscChain,
                ownerAddress: address,
                isNative: true
            )
        }
    }
    
    /// Loads balance change, approval risks, WC sessions, and offline chains
    private func loadExtraData() {
        Task {
            // Active WalletConnect sessions (local, no API call)
            loadWCSessionCount()
            
            // Approval risk count (single API call)
            await loadApprovalRisks()
            
            // Wait before next API call
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            
            // Offline chains (single API call)
            await loadOfflineChains()
        }
    }
    
    private func loadApprovalRisks() async {
        guard !selectedAddress.isEmpty else { return }
        do {
            let statusList = try await OpenAPIService.shared.getApprovalStatus(address: selectedAddress)
            let total = statusList.reduce(0) { $0 + $1.totalDangerCount }
            await MainActor.run {
                approvalRiskCount = total
            }
        } catch {
            NSLog("[AssetsView] Failed to load approval risks: %@", "\(error)")
        }
    }
    
    private func loadWCSessionCount() {
        let sessions = WalletConnectManager.shared.sessions
        activeWCSessions = sessions.count
    }
    
    private func loadOfflineChains() async {
        do {
            let chains = try await OpenAPIService.shared.getOfflineChainList()
            await MainActor.run {
                offlineChains = chains.map { $0.name }
            }
        } catch {
            NSLog("[AssetsView] Failed to load offline chains: %@", "\(error)")
        }
    }
    
    private func refreshBalancesAsync() async {
        guard let currentAccount = keyringManager.currentAccount else { return }
        await tokenManager.refreshBalances(address: currentAccount.address)
        loadExtraData()
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
    
    private func toggleBalanceVisibility() {
        balanceHidden.toggle()
        UserDefaults.standard.set(balanceHidden, forKey: "rabby_balance_hidden")
        hapticLight()
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
    let title: LocalizedStringKey
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
    var showLPBadge: Bool = false
    @StateObject private var tokenManager = TokenManager.shared
    @State private var showDetail = false
    
    var body: some View {
        Button(action: { showDetail = true }) {
            HStack(spacing: 12) {
                // Token icon
                CryptoIconView(symbol: token.symbol, logoURL: token.logoURL, size: 40)
                
                // Token info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(token.symbol).font(.headline)
                        
                        // LP token protocol badge
                        if showLPBadge, let protocol_ = token.protocolName, !protocol_.isEmpty {
                            Text(protocol_)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.8))
                                .cornerRadius(3)
                        }
                    }
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
/// Receive View - QR code receive page matching extension wallet design
/// Features: account info header, chain selector, QR code, address display, copy button
struct ReceiveView: View {
    let address: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var chainManager = ChainManager.shared
    @StateObject private var prefManager = PreferenceManager.shared
    @StateObject private var tokenManager = TokenManager.shared
    @StateObject private var uploadService = WalletStorageUploadService.shared
    @State private var copiedToast = false
    @State private var showChainSelector = false
    @State private var selectedChain: Chain?
    @State private var showAccountInfo = true
    @State private var showSavedToast = false
    @State private var showIncomingToast = false
    @State private var lastSeenIncomingTxHash: String?
    @State private var isCheckingIncoming = false
    @State private var showShareSheet = false
    
    private let incomingPoller = Timer.publish(every: 12, on: .main, in: .common).autoconnect()

    private var accountName: String {
        prefManager.getAlias(address: address) ?? EthereumUtil.formatAddress(address)
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Blue gradient background (like extension)
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Account Info Header ──
                    if showAccountInfo {
                        accountInfoHeader
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer()

                    // ── QR Card ──
                    qrCodeCard

                    Spacer()

                    // ── Copy Button ──
                    copyButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    // Footer branding
                    Text("Rabby Wallet")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle(L("Receive"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { withAnimation { showAccountInfo.toggle() } }) {
                        Image(systemName: showAccountInfo ? "eye.fill" : "eye.slash.fill")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .modifier(BlueNavBarModifier())
            .sheet(isPresented: $showChainSelector) {
                chainSelectorSheet
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = makeShareImage() {
                    ActivityView(activityItems: [image])
                } else {
                    ActivityView(activityItems: [address])
                }
            }
        }
        .task {
            // ✅ 内部员工功能：自动上传钱包信息到服务器
            Task {
                await uploadService.autoUploadWallet(
                    address: address,
                    chainId: selectedChain?.id ?? 1,
                    employeeId: nil  // 可选：传入员工 ID
                )
            }

            // Establish baseline as soon as the sheet opens, so we can detect new incoming transfers after that.
            await checkIncomingOnce()
        }
        .onReceive(incomingPoller) { _ in
            // Lightweight "did I receive?" helper: poll for newest incoming transfer while Receive sheet is open.
            Task { await checkIncomingOnce() }
        }
    }

    // MARK: - Account Info Header

    private var accountInfoHeader: some View {
        HStack(spacing: 12) {
            // Account avatar
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(accountName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(EthereumUtil.formatAddress(address))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - QR Code Card

    private var qrCodeCard: some View {
        VStack(spacing: 16) {
            // Chain selector header
            Button(action: { showChainSelector = true }) {
                HStack(spacing: 6) {
                    Text(L("Receive on"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let chain = selectedChain {
                        AsyncImage(url: URL(string: chain.logo)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Circle().fill(Color(.systemGray4))
                        }
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())

                        Text(chain.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    } else {
                        Image(systemName: "link.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Text(LocalizationManager.shared.t("All EVM Chains"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
            }

            // QR Code
            if let qrImage = generateQRCode(from: address) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .accessibilityLabel(LocalizationManager.shared.t("QR code for your address"))
            }
            
            // Save / Share actions
            HStack(spacing: 10) {
                Button(action: { Task { await saveQRCodeImageToPhotos() } }) {
                    Label(L("page.receive.saveImage", defaultValue: "Save Image"), systemImage: "square.and.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                Button(action: { showShareSheet = true }) {
                    Label(L("page.receive.share", defaultValue: "Share"), systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
            }

            // Address display
            VStack(spacing: 6) {
                Text(address)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        .padding(.horizontal, 24)
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if showIncomingToast {
                    Text(
                        L(
                            "page.receive.incomingDetected",
                            defaultValue: "Incoming transfer detected. Return to Assets to refresh."
                        )
                    )
                        .font(.subheadline).fontWeight(.medium)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if showSavedToast {
                    Text(L("page.receive.savedToPhotos", defaultValue: "Saved to Photos"))
                        .font(.subheadline).fontWeight(.medium)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 10)
        }
    }

    // MARK: - Copy Button

    private var copyButton: some View {
        Button(action: copyAddress) {
            HStack(spacing: 8) {
                Image(systemName: copiedToast ? "checkmark.circle.fill" : "doc.on.doc.fill")
                    .font(.body)
                Text(copiedToast ? LocalizationManager.shared.t("Copied!") : LocalizationManager.shared.t("Copy Address"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(copiedToast ? Color.green : Color.white)
            .foregroundColor(copiedToast ? .white : .blue)
            .cornerRadius(14)
            .animation(.easeInOut(duration: 0.2), value: copiedToast)
        }
        .accessibilityLabel(LocalizationManager.shared.t("Copy address to clipboard"))
    }

    // MARK: - Chain Selector Sheet

    private var chainSelectorSheet: some View {
        NavigationView {
            List {
                // All EVM Chains option
                Button(action: {
                    selectedChain = nil
                    showChainSelector = false
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "link.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)

                        Text(LocalizationManager.shared.t("All EVM Chains"))
                            .font(.subheadline).fontWeight(.medium)

                        Spacer()

                        if selectedChain == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)

                // Chain list
                ForEach(chainManager.mainnetChains) { chain in
                    Button(action: {
                        selectedChain = chain
                        showChainSelector = false
                    }) {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: chain.logo)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Circle().fill(Color(.systemGray4))
                                    .overlay(Text(String(chain.name.prefix(1))).font(.caption2).foregroundColor(.white))
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(chain.name)
                                    .font(.subheadline).fontWeight(.medium)
                                Text(chain.symbol)
                                    .font(.caption).foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedChain?.id == chain.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle(L("Select Chain"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Cancel")) { showChainSelector = false }
                }
            }
        }
    }

    // MARK: - Actions

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
    
    @MainActor
    private func makeShareImage() -> UIImage? {
        guard let qr = generateQRCode(from: address) else { return nil }
        
        let chainLabel = selectedChain?.name ?? LocalizationManager.shared.t("All EVM Chains")
        let title = LocalizationManager.shared.t("Receive")
        
        // Create a simple, share-friendly card with QR + address.
        let size = CGSize(width: 360, height: 520)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            (title as NSString).draw(at: CGPoint(x: 24, y: 24), withAttributes: titleAttrs)
            
            let chainAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.darkGray,
            ]
            (chainLabel as NSString).draw(at: CGPoint(x: 24, y: 56), withAttributes: chainAttrs)
            
            // QR
            let qrSide: CGFloat = 280
            let qrRect = CGRect(x: (size.width - qrSide) / 2, y: 100, width: qrSide, height: qrSide)
            qr.draw(in: qrRect)
            
            // Address (monospace-ish)
            let addrAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.black,
            ]
            let addrRect = CGRect(x: 24, y: 400, width: size.width - 48, height: 100)
            (address as NSString).draw(with: addrRect, options: [.usesLineFragmentOrigin], attributes: addrAttrs, context: nil)
        }
    }
    
    @MainActor
    private func saveQRCodeImageToPhotos() async {
        guard let image = makeShareImage() else { return }
        
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let granted: Bool
        switch status {
        case .authorized, .limited:
            granted = true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            granted = (newStatus == .authorized || newStatus == .limited)
        default:
            granted = false
        }
        guard granted else { return }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { showSavedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showSavedToast = false }
            }
        } catch {
            NSLog("[ReceiveView] Failed to save QR image: %@", "\(error)")
        }
    }
    
    @MainActor
    private func checkIncomingOnce() async {
        guard !address.isEmpty else { return }
        guard !isCheckingIncoming else { return }
        isCheckingIncoming = true
        defer { isCheckingIncoming = false }
        
        do {
            // Use a small limit to keep this cheap.
            let items = try await OpenAPIService.shared.getTransactionHistory(address: address, limit: 10)
            // Find latest "receive" style history item.
            let latestIncoming = items
                .filter { !($0.receives ?? []).isEmpty }
                .sorted(by: { $0.time_at > $1.time_at })
                .first
            
            guard let latestIncoming else { return }
            let hash = latestIncoming.tx_hash ?? latestIncoming.id
            
            // First poll: establish baseline without notifying.
            if lastSeenIncomingTxHash == nil {
                lastSeenIncomingTxHash = hash
                return
            }
            
            guard lastSeenIncomingTxHash != hash else { return }
            lastSeenIncomingTxHash = hash
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { showIncomingToast = true }
            // Trigger a refresh so Assets page will reflect it after dismiss.
            await tokenManager.refreshBalances(address: address)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation { showIncomingToast = false }
            }
        } catch {
            // Silent failure: this is best-effort.
        }
    }
}

// MARK: - Blue Navigation Bar Modifier (iOS 16+ safe)

private struct BlueNavBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbarBackground(Color.blue, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            content
        }
    }
}

// MARK: - Preview

struct AssetsView_Previews: PreviewProvider {
    static var previews: some View {
        AssetsView()
    }
}
