import SwiftUI

/// Lending View - DeFi lending/borrowing interface
/// Corresponds to: src/ui/views/DesktopLending/
struct LendingView: View {
    @StateObject private var lendingManager = LendingManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text(L("My Positions")).tag(0)
                Text(L("Markets")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if lendingManager.isLoading {
                Spacer()
                ProgressView(L("Loading..."))
                Spacer()
            } else {
                if selectedTab == 0 {
                    positionsView
                } else {
                    marketsView
                }
            }
        }
        .navigationTitle(L("Lending"))
        .onAppear { loadData() }
    }
    
    private var positionsView: some View {
        ScrollView {
            if lendingManager.positions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.columns").font(.system(size: 48)).foregroundColor(.gray)
                    Text(L("No lending positions")).foregroundColor(.secondary)
                    Text(L("Supply assets to earn interest")).font(.caption).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 60)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(lendingManager.positions) { position in
                        positionCard(position)
                    }
                }
                .padding()
            }
        }
    }
    
    private func positionCard(_ position: LendingManager.LendingPosition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(position.protocolName).font(.headline)
                Spacer()
                healthBadge(position.healthStatus)
            }
            
            if let healthRate = position.healthRate {
                HStack {
                    Text(L("Health Factor")).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", healthRate)).font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(healthColor(position.healthStatus))
                }
            }
            
            Divider()
            
            // Supply
            if !position.supplyTokens.isEmpty {
                Text(L("Supplied")).font(.caption).foregroundColor(.secondary)
                ForEach(position.supplyTokens) { token in
                    HStack {
                        Text(token.symbol).font(.subheadline)
                        Spacer()
                        Text(String(format: "%.4f", token.amount)).font(.subheadline)
                        Text("($\(String(format: "%.2f", token.value)))").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            
            // Borrow
            if !position.borrowTokens.isEmpty {
                Text(L("Borrowed")).font(.caption).foregroundColor(.secondary)
                ForEach(position.borrowTokens) { token in
                    HStack {
                        Text(token.symbol).font(.subheadline)
                        Spacer()
                        Text(String(format: "%.4f", token.amount)).font(.subheadline).foregroundColor(.red)
                        Text("($\(String(format: "%.2f", token.value)))").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            
            // Net value
            HStack {
                Text(L("Net Value")).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("$\(String(format: "%.2f", position.netValue))").font(.subheadline).fontWeight(.bold)
            }
        }
        .padding()
        .background(Color(.systemBackground)).cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    private var marketsView: some View {
        ScrollView {
            if lendingManager.protocols.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.columns").font(.system(size: 48)).foregroundColor(.gray)
                    Text(L("No lending markets found")).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 60)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(lendingManager.protocols) { proto in
                        HStack {
                            Circle().fill(Color.purple.opacity(0.2)).frame(width: 36, height: 36)
                                .overlay(Text(String(proto.name.prefix(1))).fontWeight(.bold).foregroundColor(.purple))
                            VStack(alignment: .leading) {
                                Text(proto.name).fontWeight(.medium)
                                Text(proto.chain).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if let tvl = proto.tvl {
                                Text("TVL: $\(formatLargeNumber(tvl))").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func healthBadge(_ status: LendingManager.LendingPosition.HealthStatus) -> some View {
        Text(status.rawValue.capitalized)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(healthColor(status).opacity(0.2))
            .foregroundColor(healthColor(status))
            .cornerRadius(6)
    }
    
    private func healthColor(_ status: LendingManager.LendingPosition.HealthStatus) -> Color {
        switch status { case .safe: return .green; case .warning: return .orange; case .danger: return .red; case .unknown: return .gray }
    }
    
    private func formatLargeNumber(_ num: Double) -> String {
        if num >= 1_000_000_000 { return String(format: "%.1fB", num / 1_000_000_000) }
        if num >= 1_000_000 { return String(format: "%.1fM", num / 1_000_000) }
        if num >= 1_000 { return String(format: "%.1fK", num / 1_000) }
        return String(format: "%.0f", num)
    }
    
    private func loadData() {
        guard let address = keyringManager.currentAccount?.address else { return }
        Task {
            await lendingManager.loadPositions(address: address)
            if let chain = chainManager.selectedChain {
                await lendingManager.loadProtocols(chainId: chain.serverId)
            }
        }
    }
}

/// Perps Trading View - Perpetual futures interface
/// Corresponds to: src/ui/views/Perps/ + DesktopPerps/
struct PerpsView: View {
    @StateObject private var perpsManager = PerpsManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var selectedTab = 0
    @State private var selectedCoin = "BTC"
    @State private var orderSide = "long"
    @State private var orderSize = ""
    @State private var leverage = 5
    @State private var orderType = "market"
    @State private var limitPrice = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Coin selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(perpsManager.favoritedCoins, id: \.self) { coin in
                        Button(action: { selectedCoin = coin }) {
                            Text(coin)
                                .font(.subheadline).fontWeight(selectedCoin == coin ? .bold : .regular)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(selectedCoin == coin ? Color.blue : Color(.systemGray6))
                                .foregroundColor(selectedCoin == coin ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            Picker("", selection: $selectedTab) {
                Text(L("Trade")).tag(0)
                Text(L("Positions")).tag(1)
                Text(L("Orders")).tag(2)
            }
            .pickerStyle(.segmented).padding(.horizontal)
            
            if selectedTab == 0 {
                tradeView
            } else if selectedTab == 1 {
                positionsView
            } else {
                ordersView
            }
        }
        .navigationTitle(L("Perps Trading"))
    }
    
    private var tradeView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Long/Short toggle
                HStack(spacing: 0) {
                    Button(action: { orderSide = "long" }) {
                        Text(L("Long")).fontWeight(.semibold).frame(maxWidth: .infinity).padding()
                            .background(orderSide == "long" ? Color.green : Color(.systemGray6))
                            .foregroundColor(orderSide == "long" ? .white : .primary)
                    }
                    Button(action: { orderSide = "short" }) {
                        Text(L("Short")).fontWeight(.semibold).frame(maxWidth: .infinity).padding()
                            .background(orderSide == "short" ? Color.red : Color(.systemGray6))
                            .foregroundColor(orderSide == "short" ? .white : .primary)
                    }
                }
                .cornerRadius(12)
                
                // Order type
                Picker(L("Order Type"), selection: $orderType) {
                    Text(L("Market")).tag("market")
                    Text(L("Limit")).tag("limit")
                }
                .pickerStyle(.segmented)
                
                if orderType == "limit" {
                    TextField(L("Limit Price"), text: $limitPrice)
                        .textFieldStyle(.roundedBorder).keyboardType(.decimalPad)
                }
                
                TextField(L("Size (USD)"), text: $orderSize)
                    .textFieldStyle(.roundedBorder).keyboardType(.decimalPad)
                
                // Leverage slider
                VStack(alignment: .leading) {
                    HStack {
                        Text(L("Leverage")).font(.subheadline)
                        Spacer()
                        Text("\(leverage)x").font(.subheadline).fontWeight(.bold)
                    }
                    Slider(value: Binding(get: { Double(leverage) }, set: { leverage = Int($0) }), in: 1...50, step: 1)
                }
                
                // Place order
                Button(action: placeOrder) {
                    Text("\(orderSide == "long" ? "Long" : "Short") \(selectedCoin)")
                        .fontWeight(.bold).frame(maxWidth: .infinity).padding()
                        .background(orderSide == "long" ? Color.green : Color.red)
                        .foregroundColor(.white).cornerRadius(12)
                }
                .disabled(orderSize.isEmpty)
                
                // Slippage
                HStack {
                    Text(L("Slippage Tolerance")).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", perpsManager.marketSlippage * 100))%").font(.caption)
                }
            }
            .padding()
        }
    }
    
    private var positionsView: some View {
        ScrollView {
            if perpsManager.positions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 48)).foregroundColor(.gray)
                    Text(L("No open positions")).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 60)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(perpsManager.positions) { pos in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(pos.symbol).font(.headline)
                                Text(pos.side.displayName.uppercased()).font(.caption).fontWeight(.bold)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(pos.side == .long ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                    .foregroundColor(pos.side == .long ? .green : .red)
                                    .cornerRadius(4)
                                Text("\(String(format: "%.0f", pos.leverage))x").font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text(pos.formattedPnl)
                                    .fontWeight(.bold).foregroundColor(pos.isProfitable ? .green : .red)
                            }
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(L("Entry")).font(.caption2).foregroundColor(.secondary)
                                    Text("$\(String(format: "%.2f", pos.entryPrice))").font(.caption)
                                }
                                Spacer()
                                VStack {
                                    Text(L("Mark")).font(.caption2).foregroundColor(.secondary)
                                    Text("$\(String(format: "%.2f", pos.markPrice))").font(.caption)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(L("Size")).font(.caption2).foregroundColor(.secondary)
                                    Text("$\(String(format: "%.2f", pos.size))").font(.caption)
                                }
                            }
                        }
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }
    
    private var ordersView: some View {
        ScrollView {
            if perpsManager.orders.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.clipboard").font(.system(size: 48)).foregroundColor(.gray)
                    Text(L("No open orders")).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 60)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(perpsManager.orders) { order in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(order.symbol) \(order.side.displayName)").fontWeight(.medium)
                                Text("\(order.orderType.displayName) · $\(String(format: "%.2f", order.size))").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if let price = order.price {
                                Text("@ $\(String(format: "%.2f", price))").font(.subheadline)
                            }
                            Button(action: { cancelOrder(order.id) }) {
                                Image(systemName: "xmark.circle").foregroundColor(.red)
                            }
                        }
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }
    
    private func placeOrder() {
        Task {
            let side: PositionSide = orderSide == "long" ? .long : .short
            let perpsOrderType: PerpsOrderType = orderType == "limit" ? .limit : .market
            _ = try? await perpsManager.openPosition(
                symbol: selectedCoin, side: side, size: Double(orderSize) ?? 0,
                leverage: Double(leverage),
                orderType: perpsOrderType,
                price: orderType == "limit" ? Double(limitPrice) : nil
            )
            orderSize = ""
            limitPrice = ""
        }
    }
    
    private func cancelOrder(_ id: String) {
        Task { try? await perpsManager.cancelOrder(orderId: id) }
    }
}

/// Advanced Settings View
/// Corresponds to: src/ui/views/AdvanceSettings/
struct AdvancedSettingsView: View {
    @StateObject private var prefManager = PreferenceManager.shared
    @State private var maxGasCache = true
    @State private var enabledDappAccount = true
    
    var body: some View {
        List {
            Section(L("Transaction")) {
                Toggle(L("Enable Gas Price Cache"), isOn: $maxGasCache)
                Toggle(L("Enable DApp Account Mode"), isOn: $enabledDappAccount)
            }
            
            Section(L("Developer")) {
                NavigationLink(L("Custom RPC")) { CustomRPCView() }
                NavigationLink(L("Custom Testnet")) { CustomTestnetView() }
            }
            
            Section(L("Data")) {
                Button(L("Clear Transaction Cache")) { /* TODO */ }
                Button(L("Clear Token Cache")) { /* TODO */ }
                Button(L("Reset All Settings")) { /* TODO */ }
                    .foregroundColor(.red)
            }
        }
        .navigationTitle(L("Advanced Settings"))
    }
}
