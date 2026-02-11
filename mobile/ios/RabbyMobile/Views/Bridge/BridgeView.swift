import SwiftUI

/// Bridge View - Cross-chain bridge interface
struct BridgeView: View {
    @StateObject private var bridgeManager = BridgeManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var fromChain: Chain?
    @State private var toChain: Chain?
    @State private var amount = ""
    @State private var selectedQuote: BridgeManager.BridgeQuote?
    @State private var isBridging = false
    @State private var showResult = false
    @State private var txHash: String?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Chain selector
                    HStack(spacing: 12) {
                        chainSelector(title: "From", chain: fromChain) { fromChain = $0 }
                        Button(action: swapChains) {
                            Image(systemName: "arrow.left.arrow.right").foregroundColor(.blue)
                        }
                        chainSelector(title: "To", chain: toChain) { toChain = $0 }
                    }.padding(.horizontal)
                    
                    // Amount input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount").font(.caption).foregroundColor(.secondary)
                        TextField("0.0", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }.padding(.horizontal)
                    
                    // Quotes
                    if !bridgeManager.quotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bridge Routes").font(.headline).padding(.horizontal)
                            ForEach(bridgeManager.quotes) { quote in
                                bridgeQuoteRow(quote: quote)
                            }
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red).padding(.horizontal)
                    }
                    
                    // Bridge button
                    Button(action: executeBridge) {
                        HStack {
                            if isBridging { ProgressView().tint(.white) }
                            Text(isBridging ? "Bridging..." : "Bridge")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(canBridge ? Color.blue : Color.gray)
                        .foregroundColor(.white).cornerRadius(12)
                    }
                    .disabled(!canBridge || isBridging)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Bridge")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: amount) { _ in fetchQuotes() }
        .alert("Bridge Initiated", isPresented: $showResult) {
            Button("OK") { amount = ""; selectedQuote = nil }
        } message: {
            Text("Track your bridge in transaction history.\nTx: \(txHash ?? "")")
        }
    }
    
    private var canBridge: Bool {
        fromChain != nil && toChain != nil && !amount.isEmpty && selectedQuote != nil
    }
    
    private func chainSelector(title: String, chain: Chain?, action: @escaping (Chain) -> Void) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Menu {
                ForEach(chainManager.mainnetChains) { c in
                    Button(c.name) { action(c) }
                }
            } label: {
                VStack {
                    Text(chain?.symbol ?? "?").font(.title2).fontWeight(.bold)
                    Text(chain?.name ?? "Select").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color(.systemGray6)).cornerRadius(12)
            }
        }
    }
    
    private func bridgeQuoteRow(quote: BridgeManager.BridgeQuote) -> some View {
        Button(action: { selectedQuote = quote }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(quote.aggregatorName).fontWeight(.medium)
                    Text("~\(quote.estimatedTime)").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(quote.toAmount).fontWeight(.semibold)
                    Text("Fee: \(quote.bridgeFee)").font(.caption).foregroundColor(.secondary)
                }
                if selectedQuote?.id == quote.id {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                }
            }
            .padding()
            .background(selectedQuote?.id == quote.id ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain).padding(.horizontal)
    }
    
    private func swapChains() { let t = fromChain; fromChain = toChain; toChain = t }
    
    private func fetchQuotes() {
        guard let fc = fromChain, let tc = toChain, !amount.isEmpty,
              let address = PreferenceManager.shared.currentAccount?.address else { return }
        Task {
            do {
                let q = try await bridgeManager.getQuotes(
                    fromToken: SwapManager.Token(id: fc.nativeTokenAddress, chain: fc.serverId, symbol: fc.symbol, decimals: fc.decimals, address: fc.nativeTokenAddress, logo: nil, amount: nil, price: nil),
                    toToken: SwapManager.Token(id: tc.nativeTokenAddress, chain: tc.serverId, symbol: tc.symbol, decimals: tc.decimals, address: tc.nativeTokenAddress, logo: nil, amount: nil, price: nil),
                    amount: amount, fromChain: fc, toChain: tc, userAddress: address
                )
                selectedQuote = q.first
            } catch { errorMessage = error.localizedDescription }
        }
    }
    
    private func executeBridge() {
        guard let quote = selectedQuote, let fc = fromChain,
              let address = PreferenceManager.shared.currentAccount?.address else { return }
        isBridging = true; errorMessage = nil
        Task {
            do {
                let hash = try await bridgeManager.executeBridge(quote: quote, fromAddress: address, fromChain: fc)
                txHash = hash; showResult = true
            } catch { errorMessage = error.localizedDescription }
            isBridging = false
        }
    }
}
