import SwiftUI
import BigInt

/// Send token view with Token selector, gas estimation, whitelist check, address book
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
    @State private var estimatedGas: String = ""
    @State private var estimatedGasCost: String = ""
    @State private var isEstimatingGas = false
    @State private var showWhitelistWarning = false
    @State private var showChainSelector = false

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
                        selectedToken = TokenItem(id: token.id, chainId: 0, address: token.address, symbol: token.symbol, name: token.symbol, decimals: token.decimals, logoURL: token.logo, price: token.price ?? 0, priceChange24h: nil, isNative: token.address.isEmpty || token.address == "0x")
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
            VStack(spacing: 20) {
                chainSelectorSection
                recipientSection
                tokenSelectorSection
                amountSection
                gasEstimationSection
                errorSection
                sendButtonSection
            }
            .padding(.vertical)
        }
    }

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

    private var sendButtonSection: some View {
        Button(action: sendTransaction) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isProcessing ? LocalizationManager.shared.t("Sending...") : LocalizationManager.shared.t("Send"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isProcessing || !isValid)
        .padding(.horizontal)
    }
    
    // MARK: - Sections

    private var chainSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Chain"))
                .font(.headline)

            Button(action: { showChainSelector = true }) {
                HStack(spacing: 10) {
                    chainSelectorContent

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var chainSelectorContent: some View {
        if let chain = chainManager.selectedChain {
            chainIconView(chain)
                .frame(width: 28, height: 28)
                .clipShape(Circle())

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

    private func chainIconView(_ chain: Chain) -> some View {
        Group {
            if let url = URL(string: chain.logo), chain.logo.hasPrefix("http") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        chainIconFallback(chain)
                    }
                }
            } else {
                chainIconFallback(chain)
            }
        }
    }

    private func chainIconFallback(_ chain: Chain) -> some View {
        Circle()
            .fill(Color.purple.opacity(0.15))
            .overlay(
                Text(String(chain.symbol.prefix(2)))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            )
    }

    /// Called after the user picks a different chain in the sheet.
    private func onChainChanged(_ chain: Chain) {
        // Persist selection via ChainManager
        chainManager.selectChain(chain)

        // Clear the previously-selected token (it belongs to the old chain)
        selectedToken = nil

        // Reset gas estimation fields
        estimatedGas = ""
        estimatedGasCost = ""

        // Reset amount
        amount = ""
        errorMessage = ""
    }

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Recipient"))
                    .font(.headline)
                Spacer()
                // Address book button
                Button(action: { showContactPicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle")
                        Text(L("Contacts"))
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            TextField(L("Address (0x...) or ENS"), text: $recipient)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            // Address validation indicator
            if !recipient.isEmpty {
                HStack(spacing: 4) {
                    let isValidAddr = EthereumUtil.isValidAddress(recipient)
                    Image(systemName: isValidAddr ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isValidAddr ? .green : .red)
                    Text(isValidAddr ? LocalizationManager.shared.t("Valid address") : LocalizationManager.shared.t("Invalid address"))
                        .font(.caption)
                        .foregroundColor(isValidAddr ? .green : .red)
                    
                    // Show contact name if known
                    if isValidAddr, let contact = contactBook.getContact(by: recipient) {
                        Text("(\(contact.name))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var tokenSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Token"))
                .font(.headline)
            
            Button(action: { showTokenSelector = true }) {
                HStack {
                    if let token = selectedToken {
                        // Show selected token
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(token.symbol.prefix(1)))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(token.symbol)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            if let balance = tokenManager.getCachedBalance(tokenId: token.id) {
                                Text("Balance: \(balance.balanceFormatted)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    } else {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                        Text(L("Select Token"))
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Amount"))
                    .font(.headline)
                Spacer()
                Button(L("Max")) { setMaxAmount() }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
            }
            
            HStack {
                TextField(L("0.0"), text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .onChange(of: amount) { _ in estimateGasFee() }
                
                if let token = selectedToken {
                    Text(token.symbol)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private var gasEstimationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L("Estimated Gas"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if isEstimatingGas {
                    ProgressView().scaleEffect(0.6)
                } else if !estimatedGasCost.isEmpty {
                    Text(estimatedGasCost)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Validation & Actions
    
    private var isValid: Bool {
        !recipient.isEmpty &&
        !amount.isEmpty &&
        selectedToken != nil &&
        EthereumUtil.isValidAddress(recipient)
    }
    
    private func setMaxAmount() {
        guard let token = selectedToken,
              let balance = tokenManager.getCachedBalance(tokenId: token.id) else {
            return
        }
        amount = balance.balanceFormatted
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func estimateGasFee() {
        guard isValid, let chain = chainManager.selectedChain else { return }
        isEstimatingGas = true
        Task {
            do {
                let gasLimit = try await transactionManager.estimateGas(
                    from: keyringManager.currentAccount?.address ?? "",
                    to: recipient,
                    value: "0x0",
                    data: "0x",
                    chain: chain
                )
                let gasPrice = try await transactionManager.getGasPrice(chain: chain)
                let gasCost = gasLimit * gasPrice
                let gasCostEth = Double(String(gasCost)) ?? 0
                let gasCostFormatted = gasCostEth / 1e18
                
                await MainActor.run {
                    estimatedGasCost = String(format: "~%.6f %@", gasCostFormatted, chain.nativeTokenSymbol)
                    isEstimatingGas = false
                }
            } catch {
                await MainActor.run {
                    estimatedGasCost = LocalizationManager.shared.t("Unable to estimate")
                    isEstimatingGas = false
                }
            }
        }
    }
    
    private func sendTransaction() {
        // Check whitelist
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
    
    /// Convert decimal amount string to hex Wei using Decimal for precision (no overflow)
    private func convertToWei(_ amount: String, decimals: Int) -> String {
        guard let decimalAmount = Decimal(string: amount) else {
            return "0x0"
        }
        
        let wei = decimalAmount * pow(10, decimals)
        let weiString = NSDecimalNumber(decimal: wei).stringValue
        
        // Use BigUInt if available, otherwise manual hex conversion
        // Remove any decimal point (should be integer after multiplying by 10^decimals)
        let cleanWei = weiString.components(separatedBy: ".").first ?? weiString
        guard let weiUInt = BigUInt(cleanWei) else {
            return "0x0"
        }
        return "0x" + String(weiUInt, radix: 16)
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
