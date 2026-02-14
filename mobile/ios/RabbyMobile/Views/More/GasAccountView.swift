import SwiftUI

// MARK: - Deposit Token Model

/// Supported tokens for Gas Account deposit
struct DepositToken: Identifiable, Hashable {
    let id: String
    let symbol: String
    let name: String
    let icon: String       // SF Symbol name
    let chainName: String

    static let supportedTokens: [DepositToken] = [
        DepositToken(id: "eth", symbol: "ETH", name: "Ethereum", icon: "e.circle.fill", chainName: "Ethereum"),
        DepositToken(id: "usdc", symbol: "USDC", name: "USD Coin", icon: "dollarsign.circle.fill", chainName: "Ethereum"),
        DepositToken(id: "usdt", symbol: "USDT", name: "Tether", icon: "t.circle.fill", chainName: "Ethereum"),
    ]
}

// MARK: - Gas Account View

/// Gas Account View - Login, deposit, withdraw, history, logout
/// Corresponds to: src/ui/views/GasAccount/
struct GasAccountView: View {
    @StateObject private var gasManager = GasAccountManager.shared
    @StateObject private var keyringManager = KeyringManager.shared

    // Login flow state
    @State private var isSigning = false
    @State private var loginError: String?

    // Sheet presentation
    @State private var showDepositSheet = false
    @State private var showWithdrawSheet = false
    @State private var showLogoutConfirmation = false

    // History pagination
    @State private var historyPage = 0
    private let historyPageSize = 20
    @State private var isLoadingMore = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if gasManager.isLoggedIn {
                    gasAccountCard
                    actionButtons
                    usageHistorySection
                } else {
                    loginCard
                    howItWorksSection
                }
            }
            .padding()
        }
        .navigationTitle(L("Gas Account"))
        .sheet(isPresented: $showDepositSheet) {
            DepositSheet(gasManager: gasManager)
        }
        .sheet(isPresented: $showWithdrawSheet) {
            WithdrawSheet(gasManager: gasManager, keyringManager: keyringManager)
        }
        .alert(L("Logout Gas Account"), isPresented: $showLogoutConfirmation) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Logout"), role: .destructive) {
                gasManager.logout()
            }
        } message: {
            Text(L("Are you sure you want to logout from your Gas Account? You can login again at any time."))
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if gasManager.isLoggedIn {
                    Menu {
                        Button(role: .destructive, action: { showLogoutConfirmation = true }) {
                            Label(L("Logout Gas Account"), systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Login Card (Unauthenticated State)

    private var loginCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "fuelpump.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text(L("Gas Account"))
                .font(.title2)
                .fontWeight(.bold)

            Text(L("Sign a message to activate your gas account"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(L("Pay gas fees from a single balance across all chains. No need to hold native tokens on every network."))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let error = loginError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.red)
                .padding(.horizontal)
            }

            Button(action: performLogin) {
                HStack(spacing: 8) {
                    if isSigning {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "signature")
                    }
                    Text(isSigning ? L("Signing...") : L("Sign to Login"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isSigning || keyringManager.currentAccount == nil)
            .padding(.horizontal)

            if keyringManager.currentAccount == nil {
                Text(L("No wallet connected. Import or create a wallet first."))
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
    }

    // MARK: - Gas Account Card (Authenticated State)

    private var gasAccountCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "fuelpump.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(L("Gas Account"))
                    .font(.headline)
                Spacer()
                Label(L("Active"), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Divider()

            VStack(spacing: 4) {
                Text(L("Balance"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(String(format: "%.4f", gasManager.balance))")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.primary, .primary.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                    )
                Text(L("Available for gas sponsorship"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)

            // Per-chain balance breakdown
            if !gasManager.gasBalance.isEmpty {
                Divider()
                VStack(spacing: 6) {
                    ForEach(gasManager.gasBalance) { item in
                        HStack {
                            Text(item.symbol)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("(\(item.chainId))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.4f", item.amount))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.08), .purple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { showDepositSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(L("Deposit"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            Button(action: { showWithdrawSheet = true }) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text(L("Withdraw"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Usage History Section

    private var usageHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Usage History"))
                    .font(.headline)
                Spacer()
                if !gasManager.transactions.isEmpty {
                    Text(LocalizationManager.shared.t("ios.gasAccount.itemCount", args: ["count": "\(gasManager.transactions.count)"]))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if gasManager.transactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text(L("No transactions yet"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                let visibleCount = min((historyPage + 1) * historyPageSize, gasManager.transactions.count)
                let visibleTransactions = Array(gasManager.transactions.prefix(visibleCount))

                ForEach(visibleTransactions) { tx in
                    gasTransactionRow(tx)
                }

                // Load more button for pagination
                if visibleCount < gasManager.transactions.count {
                    Button(action: loadMoreHistory) {
                        HStack {
                            if isLoadingMore {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(L("Load More"))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(isLoadingMore)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    // MARK: - How It Works (shown when logged out)

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("How Gas Account Works"))
                .font(.headline)

            infoRow(icon: "fuelpump.fill", text: LocalizationManager.shared.t("Deposit funds to your gas account"))
            infoRow(icon: "bolt.fill", text: LocalizationManager.shared.t("Gas fees are paid from your gas account balance"))
            infoRow(icon: "checkmark.shield.fill", text: LocalizationManager.shared.t("No need to hold native tokens on every chain"))
            infoRow(icon: "globe", text: LocalizationManager.shared.t("Works across all supported chains"))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Helper Views

    private func gasTransactionRow(_ tx: GasAccountManager.GasTransaction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForTransactionType(tx.type))
                .font(.title3)
                .foregroundColor(colorForTransactionType(tx.type))
                .frame(width: 32, height: 32)
                .background(colorForTransactionType(tx.type).opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayNameForType(tx.type))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(tx.date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(amountTextForTransaction(tx))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(colorForTransactionType(tx.type))
        }
        .padding(.vertical, 4)
    }

    private func iconForTransactionType(_ type: String) -> String {
        switch type {
        case "deposit":
            return "plus.circle.fill"
        case "withdraw":
            return "arrow.up.circle.fill"
        case "usage":
            return "flame.fill"
        default:
            return "circle.fill"
        }
    }

    private func colorForTransactionType(_ type: String) -> Color {
        switch type {
        case "deposit":
            return .green
        case "withdraw":
            return .orange
        case "usage":
            return .blue
        default:
            return .secondary
        }
    }

    private func displayNameForType(_ type: String) -> String {
        switch type {
        case "deposit":
            return LocalizationManager.shared.t("Deposit")
        case "withdraw":
            return LocalizationManager.shared.t("Withdraw")
        case "usage":
            return LocalizationManager.shared.t("Gas Fee")
        default:
            return type.capitalized
        }
    }

    private func amountTextForTransaction(_ tx: GasAccountManager.GasTransaction) -> String {
        switch tx.type {
        case "deposit":
            return "+$\(String(format: "%.4f", tx.amount))"
        case "withdraw":
            return "-$\(String(format: "%.4f", tx.amount))"
        case "usage":
            return "-$\(String(format: "%.4f", tx.amount))"
        default:
            return "$\(String(format: "%.4f", tx.amount))"
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Actions

    private func performLogin() {
        guard let account = keyringManager.currentAccount else {
            loginError = LocalizationManager.shared.t("No account available. Please import or create a wallet.")
            return
        }

        isSigning = true
        loginError = nil

        Task {
            do {
                let address = account.checksumAddress
                let timestamp = Int(Date().timeIntervalSince1970)
                let loginMessage = LocalizationManager.shared.t("ios.gasAccount.loginMessage", args: ["address": address, "timestamp": "\(timestamp)"])

                guard let messageData = loginMessage.data(using: .utf8) else {
                    loginError = LocalizationManager.shared.t("Failed to encode login message.")
                    isSigning = false
                    return
                }

                // Sign the personal message using KeyringManager
                let signatureData = try await keyringManager.signMessage(
                    address: account.address,
                    message: messageData
                )
                let signatureHex = "0x" + signatureData.map { String(format: "%02x", $0) }.joined()

                // Send signature to GasAccountManager to authenticate
                try await gasManager.login(address: address, signature: signatureHex)

                // Refresh balance after successful login
                try? await gasManager.loadGasBalance()

                isSigning = false
            } catch {
                loginError = error.localizedDescription
                isSigning = false
            }
        }
    }

    private func loadMoreHistory() {
        isLoadingMore = true
        historyPage += 1
        // Simulate a brief loading delay for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isLoadingMore = false
        }
    }
}

// MARK: - Deposit Sheet

/// Sheet for depositing tokens into the Gas Account
struct DepositSheet: View {
    @ObservedObject var gasManager: GasAccountManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedToken: DepositToken = DepositToken.supportedTokens[0]
    @State private var depositAmount = ""
    @State private var isDepositing = false
    @State private var depositError: String?
    @State private var copiedAddress = false

    // Placeholder gas account deposit address
    private let depositAddress = "0x4f3B4E63745d6a2EB0fD9D6b6093A2e4d86D3e1A"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Token selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Select Token"))
                            .font(.headline)

                        ForEach(DepositToken.supportedTokens) { token in
                            Button(action: { selectedToken = token }) {
                                HStack(spacing: 12) {
                                    Image(systemName: token.icon)
                                        .font(.title2)
                                        .foregroundColor(token == selectedToken ? .blue : .secondary)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            (token == selectedToken ? Color.blue : Color.secondary).opacity(0.1)
                                        )
                                        .cornerRadius(18)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(token.symbol)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Text(token.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text(token.chainName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if token == selectedToken {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(token == selectedToken ? Color.blue : Color(.systemGray4), lineWidth: 1)
                                )
                            }
                        }
                    }

                    // Amount input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Amount"))
                            .font(.headline)

                        HStack {
                            TextField(L("0.00"), text: $depositAmount)
                                .keyboardType(.decimalPad)
                                .font(.title2.weight(.medium))

                            Text(selectedToken.symbol)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Deposit address with QR
                    VStack(spacing: 12) {
                        Text(L("Gas Account Deposit Address"))
                            .font(.headline)

                        // QR placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .frame(width: 180, height: 180)

                            Image(systemName: "qrcode")
                                .font(.system(size: 120))
                                .foregroundColor(.black)
                        }
                        .shadow(color: .black.opacity(0.05), radius: 4)

                        // Address display + copy
                        HStack {
                            Text(depositAddress)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Button(action: copyAddress) {
                                Image(systemName: copiedAddress ? "checkmark" : "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(copiedAddress ? .green : .blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                        Text(LocalizationManager.shared.t("ios.gasAccount.sendToDeposit", args: ["token": selectedToken.symbol]))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if let error = depositError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }

                    // Deposit via direct send button
                    Button(action: performDeposit) {
                        HStack {
                            if isDepositing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(isDepositing ? LocalizationManager.shared.t("Sending...") : LocalizationManager.shared.t("ios.gasAccount.sendToDepositBtn", args: ["token": selectedToken.symbol]))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(depositAmount.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(depositAmount.isEmpty || isDepositing)
                }
                .padding()
            }
            .navigationTitle(L("Deposit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
        }
    }

    private func copyAddress() {
        UIPasteboard.general.string = depositAddress
        copiedAddress = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedAddress = false
        }
    }

    private func performDeposit() {
        guard let amount = Double(depositAmount), amount > 0 else {
            depositError = LocalizationManager.shared.t("Please enter a valid amount.")
            return
        }

        isDepositing = true
        depositError = nil

        Task {
            await gasManager.deposit(amount: amount)
            isDepositing = false
            dismiss()
        }
    }
}

// MARK: - Withdraw Sheet

/// Sheet for withdrawing funds from the Gas Account
struct WithdrawSheet: View {
    @ObservedObject var gasManager: GasAccountManager
    @ObservedObject var keyringManager: KeyringManager
    @Environment(\.dismiss) private var dismiss

    @State private var withdrawAmount = ""
    @State private var useCurrentAddress = true
    @State private var customAddress = ""
    @State private var isWithdrawing = false
    @State private var withdrawError: String?

    private var currentAddress: String {
        keyringManager.currentAccount?.checksumAddress ?? ""
    }

    private var targetAddress: String {
        useCurrentAddress ? currentAddress : customAddress
    }

    private var isValidAmount: Bool {
        guard let amount = Double(withdrawAmount), amount > 0 else { return false }
        return amount <= gasManager.balance
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Available balance display
                    VStack(spacing: 4) {
                        Text(L("Available Balance"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.4f", gasManager.balance))")
                            .font(.system(size: 28, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Withdraw amount
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L("Withdraw Amount"))
                                .font(.headline)
                            Spacer()
                            Button(L("Max")) {
                                withdrawAmount = String(format: "%.4f", gasManager.balance)
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }

                        HStack {
                            Text(L("$"))
                                .font(.title2)
                                .foregroundColor(.secondary)
                            TextField(L("0.00"), text: $withdrawAmount)
                                .keyboardType(.decimalPad)
                                .font(.title2.weight(.medium))
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        if let amount = Double(withdrawAmount), amount > gasManager.balance {
                            Text(L("Amount exceeds available balance"))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    // Withdraw address selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Withdraw To"))
                            .font(.headline)

                        // Current address option
                        Button(action: { useCurrentAddress = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: useCurrentAddress ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(useCurrentAddress ? .blue : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L("Current Address"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    if !currentAddress.isEmpty {
                                        Text(shortenAddress(currentAddress))
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(useCurrentAddress ? Color.blue : Color(.systemGray4), lineWidth: 1)
                            )
                        }

                        // Custom address option
                        Button(action: { useCurrentAddress = false }) {
                            HStack(spacing: 12) {
                                Image(systemName: useCurrentAddress ? "circle" : "largecircle.fill.circle")
                                    .foregroundColor(useCurrentAddress ? .secondary : .blue)

                                Text(L("Custom Address"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(useCurrentAddress ? Color(.systemGray4) : Color.blue, lineWidth: 1)
                            )
                        }

                        if !useCurrentAddress {
                            TextField(L("0x..."), text: $customAddress)
                                .font(.system(.subheadline, design: .monospaced))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)

                            if !customAddress.isEmpty && !isValidEthAddress(customAddress) {
                                Text(L("Invalid Ethereum address"))
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    if let error = withdrawError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }

                    // Withdraw button
                    Button(action: performWithdraw) {
                        HStack {
                            if isWithdrawing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                            }
                            Text(isWithdrawing ? L("Withdrawing...") : L("Withdraw"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isValidAmount && isTargetAddressValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isValidAmount || !isTargetAddressValid || isWithdrawing)
                }
                .padding()
            }
            .navigationTitle(L("Withdraw"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
        }
    }

    private var isTargetAddressValid: Bool {
        if useCurrentAddress {
            return !currentAddress.isEmpty
        }
        return isValidEthAddress(customAddress)
    }

    private func shortenAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)...\(suffix)"
    }

    private func isValidEthAddress(_ address: String) -> Bool {
        let clean = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        return clean.count == 40 && clean.allSatisfy { $0.isHexDigit }
    }

    private func performWithdraw() {
        guard let amount = Double(withdrawAmount), amount > 0 else {
            withdrawError = LocalizationManager.shared.t("Please enter a valid amount.")
            return
        }
        guard amount <= gasManager.balance else {
            withdrawError = LocalizationManager.shared.t("Amount exceeds available balance.")
            return
        }
        guard isTargetAddressValid else {
            withdrawError = LocalizationManager.shared.t("Please enter a valid withdrawal address.")
            return
        }

        isWithdrawing = true
        withdrawError = nil

        Task {
            // Use the deposit method as a placeholder for withdraw
            // In a full implementation this would call a dedicated withdraw API
            await gasManager.deposit(amount: -amount)
            isWithdrawing = false
            dismiss()
        }
    }
}

/// WalletConnect Session View - Manage WC connections
/// Corresponds to: src/ui/views/WalletConnect/
struct WalletConnectView: View {
    @StateObject private var wcManager = WalletConnectManager.shared
    @State private var pairingURI = ""
    @State private var showScanner = false
    @State private var isPairing = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection input
                VStack(spacing: 12) {
                    Text(L("Connect DApp")).font(.headline)
                    
                    TextField(L("Paste WalletConnect URI"), text: $pairingURI)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    
                    HStack(spacing: 12) {
                        Button(action: { showScanner = true }) {
                            Label(L("Scan QR"), systemImage: "qrcode.viewfinder")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color(.systemGray6)).cornerRadius(12)
                        }
                        
                        Button(action: pair) {
                            if isPairing {
                                HStack { ProgressView().tint(.white); Text(L("Connecting...")) }
                            } else {
                                Text(L("Connect"))
                            }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(pairingURI.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white).cornerRadius(12)
                        .disabled(pairingURI.isEmpty || isPairing)
                    }
                    
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                }
                .padding().background(Color(.systemBackground)).cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4)
                
                // Active sessions
                if !wcManager.sessions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Active Sessions")).font(.headline)
                        
                        ForEach(wcManager.sessions) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.peerName).fontWeight(.medium)
                                    Text(session.peerUrl).font(.caption).foregroundColor(.secondary)
                                    (Text(L("Connected")) + Text(" ") + Text(session.createdAt, style: .relative) + Text(" ") + Text(L("ago")))
                                        .font(.caption2).foregroundColor(.gray)
                                }
                                Spacer()
                                Circle().fill(Color.green).frame(width: 8, height: 8)
                            }
                            .padding().background(Color(.systemGray6)).cornerRadius(8)
                            .swipeActions {
                Button(L("Disconnect")) { Task { await wcManager.disconnectSession(session.id) } }
                                    .tint(.red)
                            }
                        }
                    }
                }
                
                // How it works
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("How to Connect")).font(.headline)
                    stepRow(number: 1, text: LocalizationManager.shared.t("Open a DApp in your browser"))
                    stepRow(number: 2, text: LocalizationManager.shared.t("Click 'Connect Wallet' and select WalletConnect"))
                    stepRow(number: 3, text: LocalizationManager.shared.t("Scan the QR code or paste the URI"))
                    stepRow(number: 4, text: LocalizationManager.shared.t("Approve the connection in Rabby"))
                }
                .padding().background(Color(.systemGray6)).cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle(L("WalletConnect"))
    }
    
    private func pair() {
        isPairing = true; errorMessage = nil
        Task {
            do {
                try await wcManager.pair(uri: pairingURI)
                pairingURI = ""
            } catch { errorMessage = error.localizedDescription }
            isPairing = false
        }
    }
    
    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Color.blue).frame(width: 24, height: 24)
                .overlay(Text("\(number)").font(.caption2).fontWeight(.bold).foregroundColor(.white))
            Text(text).font(.subheadline)
        }
    }
}

/// Chain List View - View and manage supported chains
/// Corresponds to: src/ui/views/ChainList/
struct ChainListView: View {
    @StateObject private var chainManager = ChainManager.shared
    @State private var searchText = ""
    @State private var showTestnets = false
    
    var filteredChains: [Chain] {
        let chains = showTestnets ? chainManager.mainnetChains + chainManager.testnetChains : chainManager.mainnetChains
        if searchText.isEmpty { return chains }
        return chains.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.symbol.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List {
            Toggle(L("Show Testnets"), isOn: $showTestnets)
            
            ForEach(filteredChains) { chain in
                HStack {
                    Circle().fill(Color.blue.opacity(0.2)).frame(width: 36, height: 36)
                        .overlay(Text(String(chain.symbol.prefix(2))).font(.caption).fontWeight(.bold).foregroundColor(.blue))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chain.name).fontWeight(.medium)
                        Text(LocalizationManager.shared.t("ios.gasAccount.chainId", args: ["id": "\(chain.id)"])).font(.caption).foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(chain.symbol).font(.caption).foregroundColor(.blue)
                    
                    if chain.id == chainManager.selectedChain?.id {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { chainManager.selectChain(chain) }
            }
        }
        .searchable(text: $searchText, prompt: Text(L("Search chains")))
        .navigationTitle(L("Chains"))
    }
}
