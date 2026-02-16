import SwiftUI
import BigInt

/// Send token view matching the extension wallet's design and functionality.
///
/// Extension reference: src/ui/views/SendToken/index.tsx
///
/// Features:
/// - Chain selector with logo
/// - Recipient address with validation, ENS placeholder, contact picker
/// - Token selector with real logos and balance display
/// - Amount input with USD conversion, Max button (gas-aware)
/// - Gas estimation with cost in native token + USD
/// - Balance validation (insufficient balance detection)
/// - Whitelist check before send
struct SendTokenView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var tokenManager = TokenManager.shared
    @StateObject private var transactionManager = TransactionManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @StateObject private var contactBook = ContactBookManager.shared
    @StateObject private var whitelistManager = WhitelistManager.shared
    @StateObject private var prefManager = PreferenceManager.shared
    
    @State private var recipient = ""
    @State private var amount = ""
    @State private var selectedToken: TokenItem?
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var txHash = ""
    @State private var showTokenSelector = false
    @State private var showContactPicker = false
    @State private var estimatedGasWei: UInt64 = 0
    @State private var estimatedGasCostNative: Double = 0
    @State private var estimatedGasCostUSD: Double = 0
    @State private var isEstimatingGas = false
    @State private var showWhitelistWarning = false
    @State private var showChainSelector = false
    @State private var balanceError = false
    @State private var tokenBalance: Double = 0
    @State private var tokenBalanceFormatted: String = ""
    
    /// Helper for String localization
    private func S(_ key: String) -> String { LocalizationManager.shared.t(key) }

    var body: some View {
        NavigationView {
            mainContent
        }
    }

    private var mainContent: some View {
        contentScrollView
            .navigationTitle(L("Send"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .modifier(AlertsModifier(
                showSuccess: $showSuccess,
                showWhitelistWarning: $showWhitelistWarning,
                txHash: txHash,
                onDismiss: { presentationMode.wrappedValue.dismiss() },
                onExecuteSend: executeSend
            ))
            .sheet(isPresented: $showTokenSelector) {
                TokenSelectorSheet(
                    excludeToken: selectedToken.map {
                        SwapManager.Token(id: $0.id, chain: "", symbol: $0.symbol, decimals: $0.decimals, address: $0.address, logo: $0.logoURL, amount: nil, price: $0.price)
                    },
                    onSelect: { token in
                        selectedToken = TokenItem(id: token.id, chainId: 0, address: token.address, symbol: token.symbol, name: token.symbol, decimals: token.decimals, logoURL: token.logo, price: token.price ?? 0, priceChange24h: nil, isNative: token.address.isEmpty || token.address == "0x" || token.address == "0x0000000000000000000000000000000000000000")
                        updateTokenBalance()
                        estimateGasFee()
                    }
                )
            }
            .modifier(SheetsModifier(
                showChainSelector: $showChainSelector,
                showContactPicker: $showContactPicker,
                selectedChain: $chainManager.selectedChain,
                recipient: $recipient,
                onChainSelected: onChainChanged
            ))
    }

    private var contentScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. Chain selector
                chainSelectorSection

                // 2. Recipient address
                recipientSection

                // 3. Token + Amount (combined card like extension)
                tokenAmountCard

                // 4. Gas estimation
                gasEstimationSection

                // 5. Error display
                errorSection

                // 6. Send button
                sendButtonSection
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if !errorMessage.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Send Button

    private var sendButtonSection: some View {
        Button(action: sendTransaction) {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isProcessing ? S("Sending...") : S("Send"))
                    .fontWeight(.semibold)
                    .font(.body)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSubmit ? Color.blue : Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isProcessing || !canSubmit)
        .padding(.horizontal)
    }
    
    // MARK: - Chain Selector

    private var chainSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Chain"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button(action: { showChainSelector = true }) {
                HStack(spacing: 10) {
                    chainSelectorContent
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var chainSelectorContent: some View {
        if let chain = chainManager.selectedChain {
            tokenLogo(url: chain.logo, symbol: chain.symbol, size: 28)
            Text(chain.name)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        } else {
            Image(systemName: "link.circle")
                .foregroundColor(.blue)
            Text(L("Select Chain"))
                .foregroundColor(.blue)
        }
    }

    private func onChainChanged(_ chain: Chain) {
        chainManager.selectChain(chain)
        selectedToken = nil
        estimatedGasWei = 0
        estimatedGasCostNative = 0
        estimatedGasCostUSD = 0
        amount = ""
        errorMessage = ""
        balanceError = false
        tokenBalance = 0
        tokenBalanceFormatted = ""
    }

    // MARK: - Recipient Section

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Recipient"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showContactPicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle")
                        Text(L("Contacts"))
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Address input field with paste/clear buttons
            HStack(spacing: 8) {
                TextField(L("Address (0x...) or ENS"), text: $recipient)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(recipient.isEmpty ? .body : .caption, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                if recipient.isEmpty {
                    Button(action: pasteFromClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 14))
                            Text(S("Paste"))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                } else {
                    // Clear button - shown when field has text
                    Button(action: { recipient = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .onChange(of: recipient) { _ in
                estimateGasFee()
            }
            
            // Address validation
            if !recipient.isEmpty {
                HStack(spacing: 4) {
                    let isValidAddr = EthereumUtil.isValidAddress(recipient)
                    Image(systemName: isValidAddr ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isValidAddr ? .green : .red)
                        .font(.caption)
                    Text(isValidAddr ? S("Valid address") : S("Invalid address"))
                        .font(.caption)
                        .foregroundColor(isValidAddr ? .green : .red)
                    
                    if isValidAddr, let contact = contactBook.getContact(by: recipient) {
                        Text("(\(contact.name))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    // Whitelist indicator
                    if isValidAddr && whitelistManager.isWhitelisted(recipient) {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                                .font(.caption2)
                            Text(S("Whitelisted"))
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Token + Amount Combined Card
    
    private var tokenAmountCard: some View {
        VStack(spacing: 0) {
            // Token selector row
            Button(action: { showTokenSelector = true }) {
                HStack(spacing: 10) {
                    if let token = selectedToken {
                        tokenLogo(url: token.logoURL, symbol: token.symbol, size: 36)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(token.symbol)
                                .font(.headline)
                                .foregroundColor(.primary)
                            if let chain = chainManager.selectedChain {
                                Text(chain.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text(L("Select Token"))
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            
            Divider().padding(.horizontal, 14)
            
            // Amount input area
            VStack(alignment: .leading, spacing: 8) {
                // Balance row
                if selectedToken != nil {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "wallet.pass")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(S("Balance"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(tokenBalanceFormatted.isEmpty ? "0" : tokenBalanceFormatted)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(balanceError ? .red : .primary)
                        }
                        
                        Spacer()
                        
                        Button(action: setMaxAmount) {
                            Text(L("Max"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
                
                // Amount input
                HStack(alignment: .firstTextBaseline) {
                    TextField("0.0", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .onChange(of: amount) { _ in
                            validateAmount()
                            estimateGasFee()
                        }
                    
                    if let token = selectedToken {
                        Text(token.symbol)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // USD value
                if let usdValue = amountInUSD {
                    Text(formatUSD(usdValue))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Insufficient balance warning
                if balanceError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                        Text(S("Insufficient balance"))
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Gas Estimation

    private var gasEstimationSection: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "fuelpump.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(L("Estimated Gas"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isEstimatingGas {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.6)
                        Text(S("Estimating..."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if estimatedGasCostNative > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let chain = chainManager.selectedChain {
                            Text(String(format: "~%@ %@", formatGasCost(estimatedGasCostNative), chain.symbol))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        if estimatedGasCostUSD > 0 {
                            Text(formatUSD(estimatedGasCostUSD))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Token Logo Helper
    
    private func tokenLogo(url: String?, symbol: String, size: CGFloat) -> some View {
        Group {
            if let urlStr = url, let imageURL = URL(string: urlStr), urlStr.hasPrefix("http") {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        tokenLogoFallback(symbol: symbol, size: size)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                tokenLogoFallback(symbol: symbol, size: size)
                    .frame(width: size, height: size)
            }
        }
    }
    
    private func tokenLogoFallback(symbol: String, size: CGFloat) -> some View {
        Circle()
            .fill(Color.blue.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(String(symbol.prefix(2)).uppercased())
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundColor(.blue)
            )
    }
    
    // MARK: - Computed Properties
    
    private var canSubmit: Bool {
        !recipient.isEmpty &&
        !amount.isEmpty &&
        selectedToken != nil &&
        EthereumUtil.isValidAddress(recipient) &&
        !balanceError &&
        (Double(amount) ?? 0) > 0
    }
    
    private var amountInUSD: Double? {
        guard let token = selectedToken,
              let amountDouble = Double(amount),
              amountDouble > 0,
              token.price > 0 else { return nil }
        return amountDouble * token.price
    }
    
    // MARK: - Actions
    
    private func pasteFromClipboard() {
        if let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !clipboardText.isEmpty {
            recipient = clipboardText
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    private func updateTokenBalance() {
        guard let token = selectedToken else {
            tokenBalance = 0
            tokenBalanceFormatted = ""
            return
        }
        
        if let cached = tokenManager.getCachedBalance(tokenId: token.id) {
            tokenBalanceFormatted = cached.balanceFormatted
            tokenBalance = Double(cached.balanceFormatted) ?? 0
        } else {
            tokenBalanceFormatted = "0"
            tokenBalance = 0
        }
    }
    
    private func validateAmount() {
        guard let amountDouble = Double(amount), amountDouble > 0 else {
            balanceError = false
            return
        }
        balanceError = amountDouble > tokenBalance
    }
    
    private func setMaxAmount() {
        guard let token = selectedToken else { return }
        
        if token.isNative && estimatedGasCostNative > 0 {
            // For native tokens, reserve gas
            let maxSend = tokenBalance - estimatedGasCostNative * 1.1 // 10% buffer
            if maxSend > 0 {
                amount = formatTokenAmount(maxSend, decimals: token.decimals)
            } else {
                amount = tokenBalanceFormatted
            }
        } else {
            amount = tokenBalanceFormatted
        }
        
        validateAmount()
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func estimateGasFee() {
        guard EthereumUtil.isValidAddress(recipient),
              selectedToken != nil,
              let chain = chainManager.selectedChain else { return }
        
        isEstimatingGas = true
        Task {
            do {
                // Use RPC directly for gas estimation (bypasses Rabby API rate limiting)
                let gasPriceWei: UInt64
                let rpcUrl = await MainActor.run { RPCManager.shared.getEffectiveRPC(chainId: chain.id) ?? chain.defaultRpcUrl }
                if chain.isEIP1559 {
                    let fees = try await OpenAPIService.shared.getFeeHistoryViaRPC(rpcUrl: rpcUrl)
                    gasPriceWei = fees.normal
                } else {
                    gasPriceWei = try await OpenAPIService.shared.getGasPriceViaRPC(rpcUrl: rpcUrl)
                }
                
                // Standard gas limit: 21000 for native transfer, ~65000 for ERC20
                let gasLimit: UInt64 = (selectedToken?.isNative == true) ? 21_000 : 65_000
                let gasCostWei = gasPriceWei * gasLimit
                let gasCostNative = Double(gasCostWei) / 1e18
                
                // Get native token price for USD conversion
                var gasCostUSD: Double = 0
                if let coinGeckoPrice = try? await OpenAPIService.shared.getTokenPriceFromCoinGecko(chainServerId: chain.serverId) {
                    gasCostUSD = gasCostNative * coinGeckoPrice.usdPrice
                }
                
                await MainActor.run {
                    estimatedGasWei = gasCostWei
                    estimatedGasCostNative = gasCostNative
                    estimatedGasCostUSD = gasCostUSD
                    isEstimatingGas = false
                }
            } catch {
                await MainActor.run {
                    estimatedGasCostNative = 0
                    estimatedGasCostUSD = 0
                    isEstimatingGas = false
                }
            }
        }
    }
    
    private func sendTransaction() {
        if prefManager.isWhitelistEnabled && !whitelistManager.isWhitelisted(recipient) {
            showWhitelistWarning = true
            return
        }
        executeSend()
    }
    
    private func executeSend() {
        guard let currentAccount = keyringManager.currentAccount,
              let token = selectedToken,
              let chain = chainManager.selectedChain else {
            return
        }
        
        isProcessing = true
        errorMessage = ""
        
        Task {
            do {
                let weiValue = convertToWei(amount, decimals: token.decimals)
                let transaction: EthereumTransaction
                
                if token.isNative {
                    transaction = try await transactionManager.buildTransaction(
                        from: currentAccount.address,
                        to: recipient,
                        value: weiValue,
                        chain: chain
                    )
                } else {
                    transaction = try await transactionManager.buildERC20Transfer(
                        from: currentAccount.address,
                        to: recipient,
                        tokenAddress: token.address,
                        amount: weiValue,
                        chain: chain
                    )
                }
                
                let hash = try await transactionManager.sendTransaction(transaction)
                
                await MainActor.run {
                    txHash = hash
                    showSuccess = true
                    isProcessing = false
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    // MARK: - Formatting Helpers
    
    private func convertToWei(_ amount: String, decimals: Int) -> String {
        guard let decimalAmount = Decimal(string: amount) else { return "0x0" }
        let wei = decimalAmount * pow(10, decimals)
        let weiString = NSDecimalNumber(decimal: wei).stringValue
        let cleanWei = weiString.components(separatedBy: ".").first ?? weiString
        guard let weiUInt = BigUInt(cleanWei) else { return "0x0" }
        return "0x" + String(weiUInt, radix: 16)
    }
    
    private func formatUSD(_ value: Double) -> String {
        if value < 0.01 { return "≈ <$0.01" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return "≈ " + (formatter.string(from: NSNumber(value: value)) ?? "$0.00")
    }
    
    private func formatGasCost(_ value: Double) -> String {
        if value == 0 { return "0" }
        if value < 0.000001 { return String(format: "%.9f", value) }
        if value < 0.001 { return String(format: "%.6f", value) }
        if value < 1 { return String(format: "%.4f", value) }
        return String(format: "%.2f", value)
    }
    
    private func formatTokenAmount(_ value: Double, decimals: Int) -> String {
        if value == 0 { return "0" }
        let maxDecimals = min(decimals, 8)
        let formatted = String(format: "%.\(maxDecimals)f", value)
        // Trim trailing zeros
        var result = formatted
        while result.hasSuffix("0") && result.contains(".") {
            result = String(result.dropLast())
        }
        if result.hasSuffix(".") {
            result = String(result.dropLast())
        }
        return result
    }
}

// MARK: - View Modifiers

struct AlertsModifier: ViewModifier {
    @Binding var showSuccess: Bool
    @Binding var showWhitelistWarning: Bool
    let txHash: String
    let onDismiss: () -> Void
    let onExecuteSend: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(L("Transaction Sent"), isPresented: $showSuccess) {
                Button(L("OK"), action: onDismiss)
            } message: {
                Text("Transaction hash:\n\(txHash)")
            }
            .alert(L("Whitelist Warning"), isPresented: $showWhitelistWarning) {
                Button(L("Cancel"), role: .cancel) {}
                Button(L("Send Anyway"), role: .destructive, action: onExecuteSend)
            } message: {
                Text(L("The recipient address is not in your whitelist. Are you sure you want to send?"))
            }
    }
}

struct SheetsModifier: ViewModifier {
    @Binding var showChainSelector: Bool
    @Binding var showContactPicker: Bool
    @Binding var selectedChain: Chain?
    @Binding var recipient: String
    let onChainSelected: (Chain) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showChainSelector) {
                ChainSelectorSheet(
                    selectedChain: $selectedChain,
                    onChainSelected: onChainSelected
                )
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerSheet(selectedAddress: $recipient)
            }
    }
}

// MARK: - Contact Picker Sheet

struct ContactPickerSheet: View {
    @Binding var selectedAddress: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var contactBook = ContactBookManager.shared
    
    var body: some View {
        NavigationView {
            Group {
                if contactBook.contacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(L("No contacts"))
                            .foregroundColor(.secondary)
                        Text(L("Add contacts in Settings"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    List(contactBook.contacts) { contact in
                        Button(action: {
                            selectedAddress = contact.address
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(contact.name)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text(formatAddr(contact.address))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .font(.system(.caption, design: .monospaced))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("Contacts"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
        }
    }
    
    private func formatAddr(_ addr: String) -> String {
        guard addr.count > 10 else { return addr }
        return "\(addr.prefix(6))...\(addr.suffix(4))"
    }
}

// MARK: - Preview

struct SendTokenView_Previews: PreviewProvider {
    static var previews: some View {
        SendTokenView()
    }
}
