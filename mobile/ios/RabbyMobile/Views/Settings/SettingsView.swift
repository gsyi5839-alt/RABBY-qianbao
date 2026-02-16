import SwiftUI

/// Settings View - Complete app settings
struct SettingsView: View {
    @StateObject private var prefManager = PreferenceManager.shared
    @StateObject private var autoLock = AutoLockManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    @EnvironmentObject var localization: LocalizationManager
    @State private var showBackupSheet = false
    @State private var showAddressManagement = false
    @State private var showCustomRPC = false
    @State private var showCustomTestnet = false
    @State private var showConnectedSites = false
    @State private var showSecuritySettings = false
    @State private var showAbout = false
    @State private var showLogoutConfirm = false
    @State private var showLogoutPasswordPrompt = false
    @State private var logoutPassword = ""
    @State private var logoutError = ""
    @State private var isLoggingOut = false
    
    var body: some View {
        NavigationView {
            List {
                // Account section
                Section(localization.t("settings_account")) {
                    NavigationLink(destination: AddressManagementView()) {
                        settingsRow(icon: "person.crop.circle", title: localization.t("address_management"), color: .blue)
                    }
                    NavigationLink(destination: AddressBackupView()) {
                        settingsRow(icon: "key.fill", title: localization.t("backup_seed_phrase_private_key"), color: .orange)
                    }
                    NavigationLink(destination: AddFromSeedPhraseView()) {
                        settingsRow(icon: "plus.circle", title: localization.t("add_from_seed_phrase"), color: .blue)
                    }
                }

                // Security section
                Section(localization.t("settings_security")) {
                    Toggle(isOn: Binding(
                        get: { prefManager.isWhitelistEnabled },
                        set: { prefManager.setWhitelistEnabled($0) }
                    )) {
                        settingsRow(icon: "shield.checkered", title: localization.t("whitelist"), color: .green)
                    }

                    NavigationLink(destination: WhitelistInputView()) {
                        settingsRow(icon: "list.bullet.rectangle.portrait", title: localization.t("manage_whitelist"), color: .green)
                    }

                    NavigationLink(destination: SecuritySettingsView()) {
                        settingsRow(icon: "lock.shield", title: localization.t("security_rules"), color: .red)
                    }
                    
                    // Auto lock
                    Picker(selection: Binding(
                        get: { AutoLockManager.LockDuration(rawValue: autoLock.autoLockDuration) ?? .oneHour },
                        set: { autoLock.setDuration($0.rawValue) }
                    )) {
                        ForEach(AutoLockManager.LockDuration.allCases, id: \.self) { duration in
                            Text(duration.displayName).tag(duration)
                        }
                    } label: {
                        settingsRow(icon: "lock.fill", title: localization.t("auto_lock"), color: .purple)
                    }

                    Toggle(isOn: Binding(
                        get: { BiometricAuthManager.shared.isBiometricEnabled },
                        set: { newValue in toggleBiometrics(enable: newValue) }
                    )) {
                        settingsRow(icon: BiometricAuthManager.shared.biometricType == .faceID ? "faceid" : "touchid", title: localization.t("face_id_touch_id"), color: .blue)
                    }
                    .disabled(!BiometricAuthManager.shared.canUseBiometric)
                }

                // Network section
                Section(localization.t("settings_network")) {
                    NavigationLink(destination: CustomRPCView()) {
                        settingsRow(icon: "network", title: localization.t("custom_rpc"), color: .teal)
                    }
                    NavigationLink(destination: CustomTestnetView()) {
                        settingsRow(icon: "testtube.2", title: localization.t("custom_testnet"), color: .indigo)
                    }
                    Toggle(isOn: $prefManager.showTestnet) {
                        settingsRow(icon: "eye", title: localization.t("show_testnet"), color: .gray)
                    }
                }

                // DApp section
                Section(localization.t("settings_dapp")) {
                    NavigationLink(destination: ConnectedSitesView()) {
                        settingsRow(icon: "globe", title: localization.t("connected_sites"), color: .cyan)
                    }
                    NavigationLink(destination: WalletConnectView()) {
                        settingsRow(icon: "link.circle", title: localization.t("walletconnect"), color: .blue)
                    }
                }

                // Features section
                Section(localization.t("settings_features")) {
                    NavigationLink(destination: NFTView()) {
                        settingsRow(icon: "photo.stack.fill", title: localization.t("nft_gallery"), color: .pink)
                    }
                    NavigationLink(destination: LendingView()) {
                        settingsRow(icon: "building.columns", title: localization.t("lending"), color: .purple)
                    }
                    NavigationLink(destination: PerpsView()) {
                        settingsRow(icon: "chart.line.uptrend.xyaxis", title: localization.t("perps_trading"), color: .orange)
                    }
                    NavigationLink(destination: GasAccountView()) {
                        settingsRow(icon: "fuelpump.fill", title: localization.t("gas_account"), color: .teal)
                    }
                    NavigationLink(destination: BridgeView()) {
                        settingsRow(icon: "arrow.left.arrow.right.circle", title: localization.t("bridge"), color: .indigo)
                    }
                    NavigationLink(destination: Text(localization.t("rabby_points"))) {
                        settingsRow(icon: "star.circle.fill", title: localization.t("rabby_points"), color: .orange)
                    }
                    NavigationLink(destination: TokenApprovalView()) {
                        settingsRow(icon: "checkmark.shield", title: localization.t("token_approvals"), color: .green)
                    }
                    NavigationLink(destination: NFTApprovalView()) {
                        settingsRow(icon: "photo.badge.checkmark", title: localization.t("nft_approvals"), color: .pink)
                    }
                    NavigationLink(destination: SignedTextHistoryView()) {
                        settingsRow(icon: "signature", title: localization.t("signed_messages"), color: .gray)
                    }
                    NavigationLink(destination: ChainListView()) {
                        settingsRow(icon: "link.circle.fill", title: localization.t("chain_list"), color: .blue)
                    }
                }

                // Appearance section
                Section(localization.t("settings_appearance")) {
                    Picker(selection: Binding(
                        get: { prefManager.themeMode },
                        set: { prefManager.setTheme($0) }
                    )) {
                        Text(localization.t("theme_light")).tag(PreferenceManager.ThemeMode.light)
                        Text(localization.t("theme_dark")).tag(PreferenceManager.ThemeMode.dark)
                        Text(localization.t("theme_system")).tag(PreferenceManager.ThemeMode.system)
                    } label: {
                        settingsRow(icon: "circle.lefthalf.filled", title: localization.t("theme"), color: .gray)
                    }
                    
                    Picker(selection: Binding(
                        get: { prefManager.localeMode == .system ? "system" : prefManager.locale },
                        set: { newLocale in
                            if newLocale == "system" {
                                prefManager.setLocaleModeSystem()
                            } else {
                                prefManager.setLocale(newLocale)
                            }
                        }
                    )) {
                        Text(localization.t("theme_system")).tag("system")
                        // Language names shown in their native form (not translated)
                        Text("English").tag("en")
                        Text("中文简体").tag("zh-CN")
                        Text("中文繁體").tag("zh-HK")
                        Text("日本語").tag("ja")
                        Text("한국어").tag("ko")
                        Text("Deutsch").tag("de")
                        Text("Español").tag("es")
                        Text("Français").tag("fr-FR")
                        Text("Português").tag("pt")
                        Text("Português (BR)").tag("pt-BR")
                        Text("Русский").tag("ru")
                        Text("Türkçe").tag("tr")
                        Text("Tiếng Việt").tag("vi")
                        Text("Bahasa Indonesia").tag("id")
                        Text("Українська").tag("uk-UA")
                    } label: {
                        settingsRow(icon: "globe", title: localization.t("language"), color: .blue)
                    }

                    Picker(selection: $prefManager.currency) {
                        Text(L("USD")).tag("USD")
                        Text(L("EUR")).tag("EUR")
                        Text(L("CNY")).tag("CNY")
                        Text(L("JPY")).tag("JPY")
                    } label: {
                        settingsRow(icon: "dollarsign.circle", title: localization.t("currency"), color: .green)
                    }
                }

                // About section
                Section(localization.t("settings_about")) {
                    HStack {
                        settingsRow(icon: "info.circle", title: localization.t("version"), color: .gray)
                        Spacer()
                        Text(L("0.93.77")).foregroundColor(.secondary)
                    }
                    NavigationLink(destination: AdvancedSettingsView()) {
                        settingsRow(icon: "wrench.and.screwdriver", title: localization.t("advanced"), color: .gray)
                    }
                }

                // Lock and Logout buttons
                Section {
                    Button(action: lockWallet) {
                        HStack {
                            Spacer()
                            Text(localization.t("lock_wallet")).foregroundColor(.orange).fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .accessibilityLabel(localization.t("lock_wallet"))
                    .accessibilityHint("Locks the wallet and requires authentication to access")

                    Button(action: { showLogoutConfirm = true }) {
                        HStack {
                            Spacer()
                            Text(localization.t("logout_wallet", defaultValue: "退出钱包")).foregroundColor(.red).fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .accessibilityLabel(localization.t("logout_wallet", defaultValue: "退出钱包"))
                    .accessibilityHint("Completely reset wallet - requires seed phrase to recover")
                }
            }
            .navigationTitle(localization.t("tab_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(localization.t("biometric_error"), isPresented: $showBiometricError) {
                Button(L("OK"), role: .cancel) {}
            } message: {
                Text(biometricErrorMessage)
            }
            .alert(localization.t("logout_wallet_confirm_title", defaultValue: "⚠️ 退出钱包"), isPresented: $showLogoutConfirm) {
                Button(localization.t("cancel", defaultValue: "取消"), role: .cancel) {}
                Button(localization.t("continue", defaultValue: "继续"), role: .destructive) {
                    showLogoutPasswordPrompt = true
                }
            } message: {
                Text(localization.t("logout_wallet_confirm_message", defaultValue: "此操作将永久删除当前钱包数据。\n\n⚠️ 请确保您已备份助记词或私钥，否则将永久失去资产访问权限！\n\n退出后可以重新创建新钱包或导入现有钱包。"))
            }
            .sheet(isPresented: $showLogoutPasswordPrompt) {
                LogoutPasswordPromptView(
                    isPresented: $showLogoutPasswordPrompt,
                    password: $logoutPassword,
                    errorMessage: $logoutError,
                    isLoggingOut: $isLoggingOut,
                    onConfirm: executeLogout
                )
            }
        }
    }
    
    private func settingsRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(color)
                .cornerRadius(6)
            Text(title)
        }
    }
    
    @State private var showBiometricError = false
    @State private var biometricErrorMessage = ""
    
    private func toggleBiometrics(enable: Bool) {
        if enable {
            Task {
                do {
                    let success = try await BiometricAuthManager.shared.authenticate(
                        reason: "Enable biometric unlock for Rabby Wallet"
                    )
                    if success {
                        guard let currentPassword = keyringManager.currentUnlockPassword(), !currentPassword.isEmpty else {
                            throw BiometricError.passwordNotStored
                        }
                        try BiometricAuthManager.shared.saveBiometricPassword(currentPassword)
                        BiometricAuthManager.shared.enableBiometric()
                    }
                } catch {
                    biometricErrorMessage = error.localizedDescription
                    showBiometricError = true
                }
            }
        } else {
            BiometricAuthManager.shared.disableBiometric()
        }
    }
    
    private func lockWallet() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        Task {
            await keyringManager.setLocked()
            autoLock.lock()
        }
    }

    private func executeLogout() {
        guard !logoutPassword.isEmpty else {
            logoutError = localization.t("password_required", defaultValue: "请输入密码")
            return
        }

        isLoggingOut = true
        logoutError = ""

        Task {
            do {
                // 1. 验证密码
                let valid = try await keyringManager.verifyPassword(logoutPassword)
                guard valid else {
                    await MainActor.run {
                        logoutError = localization.t("incorrect_password", defaultValue: "密码错误")
                        isLoggingOut = false
                    }
                    return
                }

                // 2. 执行退出钱包
                try await keyringManager.resetWallet()

                await MainActor.run {
                    isLoggingOut = false
                    showLogoutPasswordPrompt = false
                    logoutPassword = ""

                    // 触发震动反馈
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }

                NSLog("[SettingsView] Wallet logout successful - returning to onboarding")
            } catch {
                await MainActor.run {
                    logoutError = localization.t("logout_failed", defaultValue: "退出失败：\(error.localizedDescription)")
                    isLoggingOut = false
                }
            }
        }
    }
}


/// Address Backup View
struct AddressBackupView: View {
    @State private var showMnemonic = false
    @State private var showPrivateKey = false
    @State private var password = ""
    @State private var mnemonic: String?
    @State private var privateKey: String?
    @State private var errorMessage: String?
    @State private var isMasked = true
    @State private var copiedFeedback = false
    @State private var showScreenshotWarning = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
            // Warning
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                Text(L("Never share your seed phrase or private key with anyone. Store it securely offline."))
                    .font(.subheadline).foregroundColor(.red)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Password input
            SecureField(L("Enter password to reveal"), text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error).font(.caption).foregroundColor(.red)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: revealMnemonic) {
                    Text(L("Show Seed Phrase"))
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                }
                
                Button(action: revealPrivateKey) {
                    Text(L("Show Private Key"))
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.orange).foregroundColor(.white).cornerRadius(12)
                }
            }.padding(.horizontal)
            
            // Revealed content
            if let mnemonic = mnemonic {
                revealedContent("Seed Phrase", content: mnemonic)
            }
            
            if let privateKey = privateKey {
                revealedContent("Private Key", content: privateKey)
            }
            
            Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle(L("Backup"))
        .onDisappear { clearRevealedData() }
        .alert(L("Screenshot Detected"), isPresented: $showScreenshotWarning) {
            Button(L("I Understand"), role: .cancel) {}
        } message: {
            Text(L("Be careful! Screenshots of seed phrases and private keys can be a security risk."))
        }
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: UIApplication.userDidTakeScreenshotNotification,
                object: nil, queue: .main
            ) { _ in
                if mnemonic != nil || privateKey != nil {
                    showScreenshotWarning = true
                }
            }
        }
    }
    
    private func revealedContent(_ title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button(action: { isMasked.toggle() }) {
                    Image(systemName: isMasked ? "eye.slash" : "eye")
                }
                Button(action: { copyWithAutoClean(content) }) {
                    Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copiedFeedback ? .green : .blue)
                }
            }
            Text(isMasked ? String(repeating: "•", count: 40) : content)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    /// Copy to clipboard with auto-clear after 30 seconds
    private func copyWithAutoClean(_ content: String) {
        UIPasteboard.general.string = content
        copiedFeedback = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if UIPasteboard.general.string == content {
                UIPasteboard.general.string = ""
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedFeedback = false
        }
    }
    
    /// Clear revealed data when leaving
    private func clearRevealedData() {
        mnemonic = nil
        privateKey = nil
        password = ""
    }
    
    private func revealMnemonic() {
        guard !password.isEmpty else { errorMessage = "Enter password"; return }
        errorMessage = nil
        Task {
            do {
                let valid = try await KeyringManager.shared.verifyPassword(password)
                if valid { mnemonic = try await KeyringManager.shared.getMnemonic(password: password) }
                else { errorMessage = "Invalid password" }
            } catch { errorMessage = error.localizedDescription }
        }
    }
    
    private func revealPrivateKey() {
        guard !password.isEmpty else { errorMessage = "Enter password"; return }
        guard let address = PreferenceManager.shared.currentAccount?.address else { return }
        errorMessage = nil
        Task {
            do {
                let valid = try await KeyringManager.shared.verifyPassword(password)
                if valid { privateKey = try await KeyringManager.shared.exportPrivateKey(address: address, password: password) }
                else { errorMessage = "Invalid password" }
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Token Approval Data Model

/// Risk level for a token approval
enum ApprovalRiskLevel: String, CaseIterable {
    case safe
    case warning
    case danger

    var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .warning: return "Warning"
        case .danger: return "Danger"
        }
    }

    var color: Color {
        switch self {
        case .safe: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }
}

/// Comprehensive token approval model used by the approval list
struct TokenApproval: Identifiable {
    let id: String
    let tokenSymbol: String
    let tokenName: String
    let tokenAddress: String
    let tokenLogoURL: String?
    let tokenDecimals: Int
    let tokenBalance: Double?
    let spenderAddress: String
    let spenderName: String?
    let spenderLogoURL: String?
    let spenderIsVerified: Bool
    let allowance: String
    let isUnlimited: Bool
    let chainServerId: String
    let chainName: String
    let chainLogoURL: String?
    let riskLevel: ApprovalRiskLevel
    let approvedAt: Date?

    /// Abbreviated spender address for display
    var spenderAbbrev: String {
        guard spenderAddress.count > 14 else { return spenderAddress }
        return String(spenderAddress.prefix(6)) + "..." + String(spenderAddress.suffix(4))
    }

    /// Human-readable allowance text
    var allowanceDisplay: String {
        isUnlimited ? "Unlimited" : allowance
    }
}

// MARK: - Token Approval View

/// Token Approval View - lists all ERC-20 token approvals for the current account,
/// with search, chain filter, risk filter, detail sheet, single revoke, and batch revoke.
struct TokenApprovalView: View {
    @StateObject private var prefManager = PreferenceManager.shared

    // Data
    @State private var approvals: [TokenApproval] = []
    @State private var isLoading = false
    @State private var loadError: String?

    // Search & filter
    @State private var searchText = ""
    @State private var selectedChainFilter: String? = nil // nil = all chains
    @State private var showDangerOnly = false

    // Detail sheet
    @State private var selectedApproval: TokenApproval?
    @State private var showDetailSheet = false

    // Batch revoke
    @State private var isMultiSelectMode = false
    @State private var selectedForRevoke: Set<String> = [] // approval IDs
    @State private var isBatchRevoking = false
    @State private var batchRevokeProgress: Int = 0
    @State private var batchRevokeTotal: Int = 0

    // Revoke state
    @State private var isRevoking = false
    @State private var revokeError: String?
    @State private var showRevokeSuccess = false
    @State private var showRevokeConfirm = false
    @State private var revokeTarget: TokenApproval?
    @State private var estimatedGasCost: String?

    // Derived chain list from loaded approvals
    private var availableChains: [(serverId: String, name: String)] {
        var seen = Set<String>()
        var chains: [(String, String)] = []
        for approval in approvals {
            if !seen.contains(approval.chainServerId) {
                seen.insert(approval.chainServerId)
                chains.append((approval.chainServerId, approval.chainName))
            }
        }
        return chains.sorted { $0.1 < $1.1 }
    }

    private var filteredApprovals: [TokenApproval] {
        approvals.filter { approval in
            // Search filter
            let matchesSearch = searchText.isEmpty ||
                approval.tokenSymbol.localizedCaseInsensitiveContains(searchText) ||
                approval.tokenName.localizedCaseInsensitiveContains(searchText) ||
                approval.spenderName?.localizedCaseInsensitiveContains(searchText) == true

            // Chain filter
            let matchesChain = selectedChainFilter == nil || approval.chainServerId == selectedChainFilter

            // Risk filter
            let matchesRisk = !showDangerOnly || approval.riskLevel == .danger

            return matchesSearch && matchesChain && matchesRisk
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            contentArea

            // Batch revoke bar
            if isMultiSelectMode && !selectedForRevoke.isEmpty {
                batchRevokeBar
            }
        }
        .navigationTitle(L("Token Approvals"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !approvals.isEmpty {
                    Button(isMultiSelectMode ? LocalizationManager.shared.t("Done") : LocalizationManager.shared.t("Select")) {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode { selectedForRevoke.removeAll() }
                    }
                }
            }
        }
        .onAppear { loadApprovals() }
        .sheet(isPresented: $showDetailSheet) {
            if let approval = selectedApproval {
                ApprovalDetailSheet(
                    approval: approval,
                    onRevoke: { target in
                        showDetailSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            beginRevoke(target)
                        }
                    },
                    onDismiss: { showDetailSheet = false }
                )
            }
        }
        .alert(L("Confirm Revoke"), isPresented: $showRevokeConfirm) {
            Button(L("Cancel"), role: .cancel) { revokeTarget = nil; estimatedGasCost = nil }
            Button(L("Revoke"), role: .destructive) { executeRevoke() }
        } message: {
            if let target = revokeTarget {
                VStack {
                    Text(LocalizationManager.shared.t("ios.approval.revokeConfirmMsg", args: ["symbol": target.tokenSymbol, "spender": target.spenderName ?? target.spenderAbbrev]))
                    if let gas = estimatedGasCost {
                        Text(LocalizationManager.shared.t("ios.approval.estimatedGas", args: ["gas": gas]))
                    }
                }
            }
        }
        .alert(L("Revoke Successful"), isPresented: $showRevokeSuccess) {
            Button(L("OK")) {}
        } message: {
            Text(L("The approval has been revoked. The list will update once the transaction is confirmed."))
        }
        .alert(L("Revoke Error"), isPresented: Binding(
            get: { revokeError != nil },
            set: { if !$0 { revokeError = nil } }
        )) {
            Button(L("OK")) { revokeError = nil }
        } message: {
            Text(revokeError ?? LocalizationManager.shared.t("Unknown error"))
        }
        .overlay {
            if isRevoking || isBatchRevoking {
                revokeProgressOverlay
            }
        }
    }

    // MARK: - Extracted Body Subviews

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(L("Search by token name"), text: $searchText)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: LocalizationManager.shared.t("All Chains"), isSelected: selectedChainFilter == nil) {
                    selectedChainFilter = nil
                }
                ForEach(availableChains, id: \.serverId) { chain in
                    filterChip(title: chain.name, isSelected: selectedChainFilter == chain.serverId) {
                        selectedChainFilter = (selectedChainFilter == chain.serverId) ? nil : chain.serverId
                    }
                }

                Divider().frame(height: 20)

                filterChip(
                    title: LocalizationManager.shared.t("Danger Only"),
                    isSelected: showDangerOnly,
                    activeColor: .red
                ) {
                    showDangerOnly.toggle()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text(L("Loading approvals...")).foregroundColor(.secondary)
            }
            Spacer()
        } else if let error = loadError {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundColor(.orange)
                Text(error).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                Button(L("Retry")) { loadApprovals() }
                    .foregroundColor(.blue)
            }
            Spacer()
        } else if filteredApprovals.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text(L(approvals.isEmpty ? "No active approvals" : "No matching approvals"))
                    .foregroundColor(.secondary)
            }
            Spacer()
        } else {
            List {
                ForEach(filteredApprovals) { approval in
                    approvalRow(approval: approval)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isMultiSelectMode {
                                toggleSelection(approval.id)
                            } else {
                                selectedApproval = approval
                                showDetailSheet = true
                            }
                        }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Subviews

    private func filterChip(title: String, isSelected: Bool, activeColor: Color = .blue, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? activeColor.opacity(0.15) : Color(.systemGray6))
                .foregroundColor(isSelected ? activeColor : .primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? activeColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func approvalRow(approval: TokenApproval) -> some View {
        HStack(spacing: 12) {
            // Multi-select checkbox
            if isMultiSelectMode {
                Image(systemName: selectedForRevoke.contains(approval.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedForRevoke.contains(approval.id) ? .blue : .gray)
                    .font(.title3)
            }

            // Token icon
            ZStack(alignment: .bottomTrailing) {
                if let logoURL = approval.tokenLogoURL, let url = URL(string: logoURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        tokenIconPlaceholder(symbol: approval.tokenSymbol)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    tokenIconPlaceholder(symbol: approval.tokenSymbol)
                }

                // Chain badge
                if let chainLogo = approval.chainLogoURL, let url = URL(string: chainLogo) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 14, height: 14)
                    }
                    .frame(width: 14, height: 14)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                    .offset(x: 2, y: 2)
                }
            }

            // Token info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(approval.tokenSymbol)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    riskBadge(level: approval.riskLevel)
                }
                Text(approval.spenderName ?? approval.spenderAbbrev)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Allowance
            VStack(alignment: .trailing, spacing: 3) {
                Text(approval.allowanceDisplay)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(approval.isUnlimited ? .red : .primary)
                Text(approval.chainName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func tokenIconPlaceholder(symbol: String) -> some View {
        ZStack {
            Circle().fill(Color.blue.opacity(0.15))
            Text(String(symbol.prefix(2)).uppercased())
                .font(.caption2).fontWeight(.bold).foregroundColor(.blue)
        }
        .frame(width: 36, height: 36)
    }

    private func riskBadge(level: ApprovalRiskLevel) -> some View {
        Text(level.displayName)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(level.color.opacity(0.15))
            .foregroundColor(level.color)
            .cornerRadius(4)
    }

    private var batchRevokeBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text(LocalizationManager.shared.t("ios.approval.selectedCount", args: ["count": "\(selectedForRevoke.count)"]))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { selectAllFiltered() }) {
                    Text(L("Select All"))
                        .font(.subheadline)
                }
                .padding(.trailing, 8)

                Button(action: { beginBatchRevoke() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.shield")
                        Text(L("Revoke Selected"))
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(selectedForRevoke.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }

    private var revokeProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                if isBatchRevoking {
                    Text(LocalizationManager.shared.t("ios.approval.revokingProgress", args: ["progress": "\(batchRevokeProgress)", "total": "\(batchRevokeTotal)"]))
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                } else {
                    Text(L("Revoking approval..."))
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                }
            }
            .padding(32)
            .background(Color(.systemGray5).opacity(0.95))
            .cornerRadius(16)
        }
    }

    // MARK: - Data Loading

    private func loadApprovals() {
        guard let address = prefManager.currentAccount?.address else {
            loadError = "No active account. Please set up your wallet first."
            return
        }

        isLoading = true
        loadError = nil

        Task {
            do {
                let apiApprovals = try await OpenAPIService.shared.getTokenApprovals(address: address)
                let chainManager = ChainManager.shared

                var result: [TokenApproval] = []
                for item in apiApprovals {
                    let chain = chainManager.getChain(byServerId: item.token.chain)

                    // Determine risk level
                    let risk: ApprovalRiskLevel = {
                        if item.spender.is_verified == true { return .safe }
                        // Unlimited approvals to unverified spenders are dangerous
                        let valueNum = Double(item.value) ?? 0
                        let isUnlimited = item.value.lowercased().contains("unlimited") ||
                            item.value == "115792089237316195423570985008687907853269984665640564039457584007913129639935" ||
                            valueNum > 1e30
                        if isUnlimited { return .danger }
                        return .warning
                    }()

                    let isUnlimited = item.value.lowercased().contains("unlimited") ||
                        item.value == "115792089237316195423570985008687907853269984665640564039457584007913129639935" ||
                        (Double(item.value) ?? 0) > 1e30

                    let approval = TokenApproval(
                        id: "\(item.token.id)_\(item.spender.id)",
                        tokenSymbol: item.token.symbol,
                        tokenName: item.token.symbol,
                        tokenAddress: item.token.id,
                        tokenLogoURL: item.token.logo_url,
                        tokenDecimals: 18,
                        tokenBalance: nil,
                        spenderAddress: item.spender.id,
                        spenderName: item.spender.name,
                        spenderLogoURL: item.spender.logo_url,
                        spenderIsVerified: item.spender.is_verified ?? false,
                        allowance: isUnlimited ? "Unlimited" : formatAllowance(item.value),
                        isUnlimited: isUnlimited,
                        chainServerId: item.token.chain,
                        chainName: chain?.name ?? item.token.chain,
                        chainLogoURL: chain?.logo,
                        riskLevel: risk,
                        approvedAt: nil
                    )
                    result.append(approval)
                }

                approvals = result
                isLoading = false
            } catch {
                loadError = "Failed to load approvals: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func formatAllowance(_ value: String) -> String {
        guard let num = Double(value) else { return value }
        if num > 1_000_000 {
            return String(format: "%.2fM", num / 1_000_000)
        } else if num > 1_000 {
            return String(format: "%.2fK", num / 1_000)
        } else {
            return String(format: "%.4f", num)
        }
    }

    // MARK: - Selection

    private func toggleSelection(_ id: String) {
        if selectedForRevoke.contains(id) {
            selectedForRevoke.remove(id)
        } else {
            selectedForRevoke.insert(id)
        }
    }

    private func selectAllFiltered() {
        for approval in filteredApprovals {
            selectedForRevoke.insert(approval.id)
        }
    }

    // MARK: - Single Revoke

    private func beginRevoke(_ approval: TokenApproval) {
        revokeTarget = approval
        estimatedGasCost = nil

        Task {
            do {
                let gasCost = try await estimateRevokeGas(for: approval)
                estimatedGasCost = gasCost
            } catch {
                estimatedGasCost = "Unable to estimate"
            }
            showRevokeConfirm = true
        }
    }

    private func executeRevoke() {
        guard let target = revokeTarget else { return }
        isRevoking = true

        Task {
            do {
                try await sendRevokeTransaction(for: target)
                isRevoking = false
                showRevokeSuccess = true
                // Refresh after a brief delay to allow indexing
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    loadApprovals()
                }
            } catch {
                isRevoking = false
                revokeError = "Revoke failed: \(error.localizedDescription)"
            }
            revokeTarget = nil
        }
    }

    // MARK: - Batch Revoke

    private func beginBatchRevoke() {
        let targets = filteredApprovals.filter { selectedForRevoke.contains($0.id) }
        guard !targets.isEmpty else { return }

        isBatchRevoking = true
        batchRevokeProgress = 0
        batchRevokeTotal = targets.count

        Task {
            var failedCount = 0
            for target in targets {
                batchRevokeProgress += 1
                do {
                    try await sendRevokeTransaction(for: target)
                } catch {
                    failedCount += 1
                }
            }

            isBatchRevoking = false
            isMultiSelectMode = false
            selectedForRevoke.removeAll()

            if failedCount > 0 {
                revokeError = "\(failedCount) of \(targets.count) revocations failed."
            } else {
                showRevokeSuccess = true
            }

            // Refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                loadApprovals()
            }
        }
    }

    // MARK: - Revoke Transaction Helpers

    /// Build and send an approve(spender, 0) transaction to revoke the approval
    private func sendRevokeTransaction(for approval: TokenApproval) async throws {
        guard let address = prefManager.currentAccount?.address else {
            throw TransactionError.invalidTransaction
        }

        guard let chain = ChainManager.shared.getChain(byServerId: approval.chainServerId) else {
            throw TransactionError.invalidChain
        }

        // Build approve(spender, 0) transaction using TransactionManager
        // function selector: 0x095ea7b3
        // parameters: spender address padded to 32 bytes + uint256(0) padded to 32 bytes
        let tx = try await TransactionManager.shared.buildTokenApproval(
            from: address,
            tokenAddress: approval.tokenAddress,
            spender: approval.spenderAddress,
            amount: "0000000000000000000000000000000000000000000000000000000000000000", // uint256(0)
            chain: chain
        )

        _ = try await TransactionManager.shared.sendTransaction(tx)
    }

    /// Estimate gas cost for revoking in human-readable form
    private func estimateRevokeGas(for approval: TokenApproval) async throws -> String {
        guard let address = prefManager.currentAccount?.address else {
            throw TransactionError.invalidTransaction
        }

        guard let chain = ChainManager.shared.getChain(byServerId: approval.chainServerId) else {
            throw TransactionError.invalidChain
        }

        // Build the calldata: approve(spender, 0)
        let functionSelector = "0x095ea7b3"
        let spenderPadded = approval.spenderAddress
            .replacingOccurrences(of: "0x", with: "")
            .padLeft(toLength: 64, withPad: "0")
        let amountPadded = String(repeating: "0", count: 64)
        let callData = functionSelector + spenderPadded + amountPadded

        let gasEstimate = try await TransactionManager.shared.estimateGas(
            from: address,
            to: approval.tokenAddress,
            value: "0x0",
            data: callData,
            chain: chain
        )

        let gasPrice = try await TransactionManager.shared.getGasPrice(chain: chain)
        let gasCostWei = gasEstimate * gasPrice
        let gasCostEth = EthereumUtil.weiToEther(gasCostWei)

        return "\(gasCostEth) \(chain.symbol)"
    }
}

// MARK: - Approval Detail Sheet

/// Detailed sheet for a single token approval, showing full token/spender info and a revoke action
struct ApprovalDetailSheet: View {
    let approval: TokenApproval
    let onRevoke: (TokenApproval) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Token info card
                    GroupBox {
                        VStack(spacing: 12) {
                            // Token header
                            HStack(spacing: 12) {
                                if let logoURL = approval.tokenLogoURL, let url = URL(string: logoURL) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        tokenPlaceholder
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                } else {
                                    tokenPlaceholder
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(approval.tokenSymbol)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text(approval.tokenName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                riskBadgeLarge(level: approval.riskLevel)
                            }

                            Divider()

                            detailRow(label: "Token Address", value: approval.tokenAddress, mono: true)

                            if let balance = approval.tokenBalance {
                                detailRow(label: "Balance", value: String(format: "%.6f %@", balance, approval.tokenSymbol))
                            }

                            detailRow(label: "Chain", value: approval.chainName)
                        }
                    } label: {
                        Label(L("Token"), systemImage: "circle.hexagonpath")
                            .font(.headline)
                    }

                    // Spender info card
                    GroupBox {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                if let logoURL = approval.spenderLogoURL, let url = URL(string: logoURL) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        spenderPlaceholder
                                    }
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    spenderPlaceholder
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(approval.spenderName ?? "Unknown Contract")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        if approval.spenderIsVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                        }
                                    }
                                    Text(approval.spenderAbbrev)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .font(.system(.caption, design: .monospaced))
                                }
                                Spacer()
                            }

                            Divider()

                            detailRow(label: "Contract Address", value: approval.spenderAddress, mono: true)

                            detailRow(
                                label: "Security Status",
                                value: approval.spenderIsVerified ? "Verified" : "Unverified",
                                valueColor: approval.spenderIsVerified ? .green : .orange
                            )
                        }
                    } label: {
                        Label(L("Spender"), systemImage: "building.2")
                            .font(.headline)
                    }

                    // Approval details card
                    GroupBox {
                        VStack(spacing: 12) {
                            HStack {
                                Text(L("Approved Amount"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(approval.allowanceDisplay)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(approval.isUnlimited ? .red : .primary)
                            }

                            if let date = approval.approvedAt {
                                HStack {
                                    Text(L("Approved At"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(date, style: .date)
                                        .font(.subheadline)
                                }
                            }

                            HStack {
                                Text(L("Risk Level"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                riskBadgeLarge(level: approval.riskLevel)
                            }
                        }
                    } label: {
                        Label(L("Approval"), systemImage: "checkmark.shield")
                            .font(.headline)
                    }

                    // Risk warning
                    if approval.riskLevel == .danger || approval.isUnlimited {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(L("This approval grants unlimited access to your tokens. It is recommended to revoke or reduce the approval amount."))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(10)
                    }

                    // Revoke button
                    Button(action: { onRevoke(approval) }) {
                        HStack {
                            Image(systemName: "xmark.shield.fill")
                            Text(L("Revoke Approval"))
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle(L("Approval Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { onDismiss() }
                }
            }
        }
    }

    // MARK: - Detail Subviews

    private func detailRow(label: String, value: String, mono: Bool = false, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(mono ? .system(.caption, design: .monospaced) : .caption)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func riskBadgeLarge(level: ApprovalRiskLevel) -> some View {
        HStack(spacing: 3) {
            Image(systemName: level == .safe ? "checkmark.circle.fill" : level == .warning ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                .font(.caption2)
            Text(level.displayName)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(level.color.opacity(0.15))
        .foregroundColor(level.color)
        .cornerRadius(6)
    }

    private var tokenPlaceholder: some View {
        ZStack {
            Circle().fill(Color.blue.opacity(0.15))
            Text(String(approval.tokenSymbol.prefix(2)).uppercased())
                .font(.caption).fontWeight(.bold).foregroundColor(.blue)
        }
        .frame(width: 44, height: 44)
    }

    private var spenderPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15))
            Image(systemName: "doc.text")
                .font(.caption).foregroundColor(.gray)
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - Logout Password Prompt View

/// 退出钱包密码确认视图
struct LogoutPasswordPromptView: View {
    @EnvironmentObject var localization: LocalizationManager
    @Binding var isPresented: Bool
    @Binding var password: String
    @Binding var errorMessage: String
    @Binding var isLoggingOut: Bool
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 警告图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.red)
                    .padding(.top, 40)

                // 标题和说明
                VStack(spacing: 12) {
                    Text(localization.t("logout_password_prompt_title", defaultValue: "最后确认"))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(localization.t("logout_password_prompt_message", defaultValue: "请输入密码以确认退出钱包。\n\n此操作不可撤销，请确保已备份助记词！"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // 密码输入
                VStack(alignment: .leading, spacing: 8) {
                    SecureField(localization.t("enter_password", defaultValue: "输入密码"), text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .padding(.horizontal)
                        .onSubmit {
                            if !password.isEmpty && !isLoggingOut {
                                onConfirm()
                            }
                        }

                    if !errorMessage.isEmpty {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()

                // 确认按钮
                Button(action: onConfirm) {
                    HStack {
                        if isLoggingOut {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isLoggingOut
                            ? localization.t("logging_out", defaultValue: "退出中...")
                            : localization.t("confirm_logout", defaultValue: "确认退出"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(password.isEmpty || isLoggingOut ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(password.isEmpty || isLoggingOut)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle(localization.t("logout_wallet", defaultValue: "退出钱包"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localization.t("cancel", defaultValue: "取消")) {
                        isPresented = false
                        password = ""
                        errorMessage = ""
                    }
                    .disabled(isLoggingOut)
                }
            }
        }
    }
}

/// Security Settings View
struct SecuritySettingsView: View {
    @StateObject private var securityEngine = SecurityEngineManager.shared
    
    var body: some View {
        List(securityEngine.rules) { rule in
            Toggle(isOn: Binding(
                get: { rule.enable },
                set: { securityEngine.setRuleEnabled(ruleId: rule.id, enabled: $0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(rule.name).fontWeight(.medium)
                        riskBadge(level: rule.level)
                    }
                    Text(rule.description).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(L("Security Rules"))
    }
    
    private func riskBadge(level: SecurityEngineManager.RiskLevel) -> some View {
        Text(level.rawValue.capitalized)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(badgeColor(level).opacity(0.2))
            .foregroundColor(badgeColor(level))
            .cornerRadius(4)
    }
    
    private func badgeColor(_ level: SecurityEngineManager.RiskLevel) -> Color {
        switch level {
        case .safe: return .green
        case .warning: return .orange
        case .danger: return .red
        case .forbidden: return .red
        }
    }
}

/// Custom RPC View
struct CustomRPCView: View {
    @StateObject private var rpcManager = RPCManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var selectedChain: Chain?
    @State private var showChainPicker = false
    @State private var rpcUrl = ""
    @State private var alias = ""
    @State private var errorMessage: String?
    @State private var testingRPC: Int?  // chainId being tested

    var body: some View {
        List {
            // Add Custom RPC Section
            Section {
                // Chain Selection
                Button(action: { showChainPicker = true }) {
                    HStack {
                        Text(L("Chain"))
                        Spacer()
                        if let chain = selectedChain {
                            Text(chain.name)
                                .foregroundColor(.secondary)
                        } else {
                            Text(L("Select Chain"))
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // RPC URL Input
                TextField(L("RPC URL"), text: $rpcUrl)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled(true)

                // Alias Input (Optional)
                TextField(L("Alias (Optional)"), text: $alias)

                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // Add Button
                Button(action: addRPC) {
                    Text(L("Add RPC"))
                }
                .disabled(selectedChain == nil || rpcUrl.isEmpty)
            } header: {
                Text(L("Add Custom RPC"))
            }

            // Custom RPCs List
            if !rpcManager.customRPCs.isEmpty {
                Section {
                    ForEach(Array(rpcManager.customRPCs.keys.sorted()), id: \.self) { chainId in
                        if let rpcItem = rpcManager.customRPCs[chainId],
                           let chain = chainManager.getChain(id: chainId) {
                            customRPCRow(chain: chain, rpcItem: rpcItem)
                        }
                    }
                    .onDelete(perform: deleteRPC)
                } header: {
                    Text(L("Custom RPCs"))
                }
            } else {
                Section {
                    Text(L("No custom RPCs"))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } header: {
                    Text(L("Custom RPCs"))
                }
            }
        }
        .navigationTitle(L("Custom RPC"))
        .sheet(isPresented: $showChainPicker) {
            chainPickerSheet
        }
    }

    // MARK: - Custom RPC Row

    private func customRPCRow(chain: Chain, rpcItem: RPCItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chain.name)
                        .fontWeight(.medium)

                    if let alias = rpcItem.alias, !alias.isEmpty {
                        Text(alias)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Text(rpcItem.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // RPC Status
                if testingRPC == chain.id {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let status = rpcManager.getRPCStatus(chainId: chain.id) {
                    Image(systemName: status.available ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(status.available ? .green : .red)
                        .font(.caption)
                }

                // Enable Toggle
                Toggle("", isOn: Binding(
                    get: { rpcItem.enable },
                    set: { rpcManager.setRPCEnable(chainId: chain.id, enable: $0) }
                ))
                .labelsHidden()
            }

            // Test Button
            Button(action: { testRPC(chainId: chain.id) }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                    Text(L("Test Connection"))
                        .font(.caption2)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
            .disabled(testingRPC == chain.id)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Chain Picker Sheet

    private var chainPickerSheet: some View {
        NavigationView {
            List {
                // Mainnet Chains
                Section(L("Mainnet")) {
                    ForEach(chainManager.mainnetChains, id: \.id) { chain in
                        Button(action: {
                            selectedChain = chain
                            showChainPicker = false
                        }) {
                            HStack {
                                Text(chain.name)
                                Spacer()
                                if selectedChain?.id == chain.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                // Testnet Chains
                if !chainManager.testnetChains.isEmpty {
                    Section(L("Testnet")) {
                        ForEach(chainManager.testnetChains, id: \.id) { chain in
                            Button(action: {
                                selectedChain = chain
                                showChainPicker = false
                            }) {
                                HStack {
                                    Text(chain.name)
                                    Spacer()
                                    if selectedChain?.id == chain.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle(L("Select Chain"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Cancel")) {
                        showChainPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func addRPC() {
        guard let chain = selectedChain else {
            errorMessage = "Please select a chain"
            return
        }

        guard !rpcUrl.isEmpty else {
            errorMessage = "Please enter RPC URL"
            return
        }

        // Validate URL format
        guard rpcManager.isValidRPCURL(rpcUrl) else {
            errorMessage = "Invalid RPC URL format"
            return
        }

        // Add RPC
        rpcManager.setRPC(
            chainId: chain.id,
            url: rpcUrl,
            alias: alias.isEmpty ? nil : alias
        )

        // Clear form
        selectedChain = nil
        rpcUrl = ""
        alias = ""
        errorMessage = nil

        // Test the new RPC
        testRPC(chainId: chain.id)
    }

    private func deleteRPC(at offsets: IndexSet) {
        let sortedKeys = Array(rpcManager.customRPCs.keys.sorted())
        offsets.forEach { index in
            let chainId = sortedKeys[index]
            rpcManager.removeCustomRPC(chainId: chainId)
        }
    }

    private func testRPC(chainId: Int) {
        testingRPC = chainId
        Task {
            let _ = await rpcManager.ping(chainId: chainId)
            await MainActor.run {
                testingRPC = nil
            }
        }
    }
}

/// Custom Testnet View
struct CustomTestnetView: View {
    @StateObject private var testnetManager = CustomTestnetManager.shared
    @State private var showAddForm = false
    
    var body: some View {
        List {
            if testnetManager.getList().isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Text(L("No custom testnets")).foregroundColor(.secondary)
                        Button(L("Add Testnet")) { showAddForm = true }
                    }.frame(maxWidth: .infinity)
                }
            } else {
                ForEach(testnetManager.getList()) { testnet in
                    HStack(spacing: 12) {
                        // Chain logo
                        chainLogo(testnet)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(testnet.name)
                                .fontWeight(.medium)
                            Text("Chain ID: \(testnet.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(testnet.rpcUrl)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(testnet.nativeTokenSymbol)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    let testnets = testnetManager.getList()
                    indexSet.forEach { testnetManager.remove(chainId: testnets[$0].id) }
                }
            }
        }
        .navigationTitle(L("Custom Testnets"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddForm = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddForm) {
            AddTestnetView()
        }
    }

    // MARK: - Chain Logo Helper

    /// 显示测试网 logo（带 AsyncImage 和 fallback）
    private func chainLogo(_ testnet: TestnetChain) -> some View {
        Group {
            if let url = URL(string: testnet.logo), testnet.logo.hasPrefix("http") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .empty:
                        logoPlaceholder(testnet)
                            .overlay(ProgressView().scaleEffect(0.5))
                    case .failure:
                        logoPlaceholder(testnet)
                    @unknown default:
                        logoPlaceholder(testnet)
                    }
                }
            } else {
                logoPlaceholder(testnet)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }

    /// Logo 占位符（使用代币符号首字母）
    private func logoPlaceholder(_ testnet: TestnetChain) -> some View {
        Circle()
            .fill(Color.purple.opacity(0.15))
            .overlay(
                Text(String(testnet.nativeTokenSymbol.prefix(2)))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            )
    }
}

/// Add Testnet View
struct AddTestnetView: View {
    @State private var chainId = ""
    @State private var name = ""
    @State private var symbol = ""
    @State private var rpcUrl = ""
    @State private var scanLink = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField(L("Chain ID"), text: $chainId).keyboardType(.numberPad)
                TextField(L("Chain Name"), text: $name)
                TextField(L("Native Token Symbol"), text: $symbol)
                TextField(L("RPC URL"), text: $rpcUrl).keyboardType(.URL).autocapitalization(.none)
                TextField(L("Block Explorer URL (optional)"), text: $scanLink).keyboardType(.URL).autocapitalization(.none)
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                
                Button(action: addTestnet) {
                    HStack {
                        if isAdding { ProgressView() }
                        Text(isAdding ? "Adding..." : "Add Testnet")
                    }
                }.disabled(chainId.isEmpty || name.isEmpty || rpcUrl.isEmpty || isAdding)
            }
            .navigationTitle(L("Add Testnet"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button(L("Cancel")) { dismiss() } }
            }
        }
    }

    private func addTestnet() {
        guard let id = Int(chainId) else { errorMessage = "Invalid Chain ID"; return }
        isAdding = true; errorMessage = nil
        Task {
            let chain = TestnetChainBase(
                id: id,
                name: name,
                nativeTokenSymbol: symbol,
                rpcUrl: rpcUrl,
                scanLink: scanLink.isEmpty ? nil : scanLink
            )
            let result = await CustomTestnetManager.shared.add(chain)
            await MainActor.run {
                isAdding = false
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorMessage = error.message
                }
            }
        }
    }
}
