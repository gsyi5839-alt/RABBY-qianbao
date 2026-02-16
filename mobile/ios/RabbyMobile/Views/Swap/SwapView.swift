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
    @State private var showFromTokenSelector = false
    @State private var showToTokenSelector = false
    @State private var isSwapping = false
    @State private var showSlippageSheet = false
    @State private var slippageValue: Double = 0.5
    @State private var isAutoSlippage: Bool = true
    @State private var showResult = false
    @State private var txHash: String?
    @State private var errorMessage: String?
    @State private var quoteTask: Task<Void, Never>?
    
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
                        Text(L("Slippage"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { showSlippageSheet = true }) {
                            HStack(spacing: 6) {
                                Text(isAutoSlippage ? LocalizationManager.shared.t("Auto") : "\(formatSlippageDisplay(slippageValue))%")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Image(systemName: "gearshape")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Quotes list
                    if !swapManager.quotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Best Quotes"))
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
                            Text(isSwapping ? LocalizationManager.shared.t("Swapping...") : LocalizationManager.shared.t("Swap"))
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
            .navigationTitle(L("Swap"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: fromAmount) { _ in scheduleFetchQuotes() }
        .onChange(of: fromToken?.id) { _ in scheduleFetchQuotes() }
        .onChange(of: toToken?.id) { _ in scheduleFetchQuotes() }
        .onChange(of: slippageValue) { _ in scheduleFetchQuotes() }
        .onChange(of: isAutoSlippage) { _ in scheduleFetchQuotes() }
        .onDisappear {
            quoteTask?.cancel()
        }
        .sheet(isPresented: $showSlippageSheet) {
            SlippageSettingsSheet(
                slippage: $slippageValue,
                isAutoSlippage: $isAutoSlippage
            )
            .modifier(SheetPresentationModifier(detents: [.medium, .large]))
        }
        .sheet(isPresented: $showFromTokenSelector) {
            TokenSelectorSheet(
                excludeToken: toToken,
                onSelect: { token in
                    fromToken = token
                    fromAmount = ""
                    selectedQuote = nil
                    scheduleFetchQuotes()
                }
            )
            .modifier(SheetPresentationModifier(detents: [.large]))
        }
        .sheet(isPresented: $showToTokenSelector) {
            TokenSelectorSheet(
                excludeToken: fromToken,
                onSelect: { token in
                    toToken = token
                    selectedQuote = nil
                    scheduleFetchQuotes()
                }
            )
            .modifier(SheetPresentationModifier(detents: [.large]))
        }
        .onAppear {
            // Sync local state from SwapManager
            isAutoSlippage = swapManager.autoSlippage
            slippageValue = Double(swapManager.slippage) ?? 0.5
        }
        .alert(L("Swap Successful"), isPresented: $showResult) {
            Button(L("OK")) { resetForm() }
        } message: {
            Text(LocalizationManager.shared.t("ios.swap.txResult", args: ["hash": txHash ?? ""]))
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
                    if isFrom {
                        showFromTokenSelector = true
                    } else {
                        showToTokenSelector = true
                    }
                }) {
                    HStack {
                        if let token = token {
                            Text(token.symbol).fontWeight(.semibold)
                        } else {
                            Text(L("Select")).foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.down").font(.caption)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(.systemGray5)).cornerRadius(8)
                }
                
                if isFrom {
                    TextField(L("0.0"), text: amount)
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
    
    private func scheduleFetchQuotes() {
        quoteTask?.cancel()
        guard let from = fromToken, let to = toToken, !fromAmount.isEmpty,
              let chain = chainManager.getChain(serverId: from.chain) else {
            selectedQuote = nil
            swapManager.quotes = []
            return
        }
        guard let address = PreferenceManager.shared.currentAccount?.address, !address.isEmpty else {
            errorMessage = "No wallet address selected"
            selectedQuote = nil
            swapManager.quotes = []
            return
        }

        quoteTask = Task {
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                let quotes = try await swapManager.getQuotes(
                    fromToken: from,
                    toToken: to,
                    amount: fromAmount,
                    chain: chain,
                    userAddress: address
                )
                guard !Task.isCancelled else { return }
                selectedQuote = quotes.first
                errorMessage = quotes.isEmpty ? "No quote available" : nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func executeSwap() {
        quoteTask?.cancel()
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

    private func formatSlippageDisplay(_ value: Double) -> String {
        if value == value.rounded() && value == Double(Int(value)) {
            return String(format: "%.0f", value)
        }
        let formatted = String(format: "%.2f", value)
        var result = formatted
        while result.hasSuffix("0") { result = String(result.dropLast()) }
        if result.hasSuffix(".") { result = String(result.dropLast()) }
        return result
    }
}
