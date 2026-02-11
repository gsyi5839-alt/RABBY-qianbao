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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Recipient section
                    recipientSection
                    
                    // Token selector
                    tokenSelectorSection
                    
                    // Amount section
                    amountSection
                    
                    // Gas estimation
                    gasEstimationSection
                    
                    // Error
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
                    
                    // Send button
                    Button(action: sendTransaction) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isProcessing ? "Sending..." : "Send")
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
                .padding(.vertical)
            }
            .navigationTitle("Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Transaction Sent", isPresented: $showSuccess) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Transaction hash:\n\(txHash)")
            }
            .alert("Whitelist Warning", isPresented: $showWhitelistWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Send Anyway", role: .destructive) {
                    executeSend()
                }
            } message: {
                Text("The recipient address is not in your whitelist. Are you sure you want to send?")
            }
            .sheet(isPresented: $showTokenSelector) {
                TokenSelectorSheet(selectedToken: $selectedToken, address: keyringManager.currentAccount?.address ?? "")
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerSheet(selectedAddress: $recipient)
            }
        }
    }
    
    // MARK: - Sections
    
    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recipient")
                    .font(.headline)
                Spacer()
                // Address book button
                Button(action: { showContactPicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle")
                        Text("Contacts")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            TextField("Address (0x...) or ENS", text: $recipient)
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
                    Text(isValidAddr ? "Valid address" : "Invalid address")
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
            Text("Token")
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
                        Text("Select Token")
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
                Text("Amount")
                    .font(.headline)
                Spacer()
                Button("Max") { setMaxAmount() }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
            }
            
            HStack {
                TextField("0.0", text: $amount)
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
                Text("Estimated Gas")
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
                    estimatedGasCost = "Unable to estimate"
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

// MARK: - Token Selector Sheet

struct TokenSelectorSheet: View {
    @Binding var selectedToken: TokenItem?
    let address: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var tokenManager = TokenManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            List {
                // Available tokens
                let tokens = filteredTokens
                if tokens.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("No tokens found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(tokens, id: \.id) { token in
                        Button(action: {
                            selectedToken = token
                            dismiss()
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 36, height: 36)
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
                                    Text(token.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let balance = tokenManager.getCachedBalance(tokenId: token.id) {
                                    Text(balance.balanceFormatted)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                if selectedToken?.id == token.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search tokens")
            .navigationTitle("Select Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var filteredTokens: [TokenItem] {
        guard let chain = chainManager.selectedChain else { return [] }
        let key = "\(address.lowercased())_\(chain.id)"
        let tokens = tokenManager.tokens[key] ?? []
        if searchText.isEmpty { return tokens }
        return tokens.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
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
                        Text("No contacts")
                            .foregroundColor(.secondary)
                        Text("Add contacts in Settings")
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
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
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
