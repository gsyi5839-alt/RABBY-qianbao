import SwiftUI

/// Swap View - Token swap interface
struct SwapView: View {
    @StateObject private var swapManager = SwapManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var fromAmount = ""
    @State private var toAmount = ""
    @State private var fromToken: SwapManager.Token?
    @State private var toToken: SwapManager.Token?
    @State private var selectedQuote: SwapManager.SwapQuote?
    @State private var showTokenSelector = false
    @State private var isSelectingFrom = true
    @State private var isSwapping = false
    @State private var showSlippageSheet = false
    @State private var showResult = false
    @State private var txHash: String?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // From token card
                    tokenCard(title: "From", token: fromToken, amount: $fromAmount, isFrom: true)
                    
                    // Swap direction button
                    Button(action: swapTokens) {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, -8)
                    
                    // To token card
                    tokenCard(title: "To", token: toToken, amount: .constant(selectedQuote?.toAmount ?? ""), isFrom: false)
                    
                    // Slippage setting
                    HStack {
                        Text("Slippage")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { showSlippageSheet = true }) {
                            Text(swapManager.autoSlippage ? "Auto" : "\(swapManager.slippage)%")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Quotes list
                    if !swapManager.quotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Best Quotes")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(swapManager.quotes) { quote in
                                quoteRow(quote: quote)
                            }
                        }
                    }
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Swap button
                    Button(action: executeSwap) {
                        HStack {
                            if isSwapping {
                                ProgressView().tint(.white)
                            }
                            Text(isSwapping ? "Swapping..." : "Swap")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSwap ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSwap || isSwapping)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Swap")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: fromAmount) { _ in fetchQuotes() }
        .alert("Swap Successful", isPresented: $showResult) {
            Button("OK") { resetForm() }
        } message: {
            Text("Transaction: \(txHash ?? "")")
        }
    }
    
    private var canSwap: Bool {
        fromToken != nil && toToken != nil && !fromAmount.isEmpty && selectedQuote != nil
    }
    
    private func tokenCard(title: String, token: SwapManager.Token?, amount: Binding<String>, isFrom: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundColor(.secondary)
            HStack {
                Button(action: {
                    isSelectingFrom = isFrom
                    showTokenSelector = true
                }) {
                    HStack {
                        if let token = token {
                            Text(token.symbol).fontWeight(.semibold)
                        } else {
                            Text("Select").foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.down").font(.caption)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(.systemGray5)).cornerRadius(8)
                }
                
                if isFrom {
                    TextField("0.0", text: amount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title2)
                } else {
                    Text(amount.wrappedValue.isEmpty ? "0.0" : amount.wrappedValue)
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func quoteRow(quote: SwapManager.SwapQuote) -> some View {
        Button(action: { selectedQuote = quote }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(quote.dexName).fontWeight(.medium)
                    Text("Gas: \(quote.gasFee)").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(quote.toAmount).fontWeight(.semibold)
                    Text("Impact: \(quote.priceImpact)").font(.caption).foregroundColor(.secondary)
                }
                if selectedQuote?.id == quote.id {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                }
            }
            .padding()
            .background(selectedQuote?.id == quote.id ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    private func swapTokens() {
        let temp = fromToken; fromToken = toToken; toToken = temp
        fromAmount = ""; selectedQuote = nil
    }
    
    private func fetchQuotes() {
        guard let from = fromToken, let to = toToken, !fromAmount.isEmpty,
              let chain = chainManager.getChain(serverId: from.chain) else { return }
        Task {
            do {
                let quotes = try await swapManager.getQuotes(fromToken: from, toToken: to, amount: fromAmount, chain: chain)
                selectedQuote = quotes.first
            } catch { errorMessage = error.localizedDescription }
        }
    }
    
    private func executeSwap() {
        guard let quote = selectedQuote, let from = fromToken,
              let chain = chainManager.getChain(serverId: from.chain),
              let address = PreferenceManager.shared.currentAccount?.address else { return }
        isSwapping = true; errorMessage = nil
        Task {
            do {
                let hash = try await swapManager.executeSwap(quote: quote, fromAddress: address, chain: chain)
                txHash = hash; showResult = true
            } catch { errorMessage = error.localizedDescription }
            isSwapping = false
        }
    }
    
    private func resetForm() { fromAmount = ""; selectedQuote = nil; txHash = nil }
}
