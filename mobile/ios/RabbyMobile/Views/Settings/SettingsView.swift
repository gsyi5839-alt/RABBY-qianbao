import SwiftUI

/// Settings View - Complete app settings
struct SettingsView: View {
    @StateObject private var prefManager = PreferenceManager.shared
    @StateObject private var autoLock = AutoLockManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var showBackupSheet = false
    @State private var showAddressManagement = false
    @State private var showCustomRPC = false
    @State private var showCustomTestnet = false
    @State private var showConnectedSites = false
    @State private var showSecuritySettings = false
    @State private var showAbout = false
    
    var body: some View {
        NavigationView {
            List {
                // Account section
                Section("Account") {
                    NavigationLink(destination: AddressManagementView()) {
                        settingsRow(icon: "person.crop.circle", title: "Address Management", color: .blue)
                    }
                    NavigationLink(destination: AddressBackupView()) {
                        settingsRow(icon: "key.fill", title: "Backup Seed Phrase / Private Key", color: .orange)
                    }
                    NavigationLink(destination: AddFromSeedPhraseView()) {
                        settingsRow(icon: "plus.circle", title: "Add From Seed Phrase", color: .blue)
                    }
                }
                
                // Security section
                Section("Security") {
                    Toggle(isOn: Binding(
                        get: { prefManager.isWhitelistEnabled },
                        set: { prefManager.setWhitelistEnabled($0) }
                    )) {
                        settingsRow(icon: "shield.checkered", title: "Whitelist", color: .green)
                    }
                    
                    NavigationLink(destination: WhitelistInputView()) {
                        settingsRow(icon: "list.bullet.rectangle.portrait", title: "Manage Whitelist", color: .green)
                    }
                    
                    NavigationLink(destination: SecuritySettingsView()) {
                        settingsRow(icon: "lock.shield", title: "Security Rules", color: .red)
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
                        settingsRow(icon: "lock.fill", title: "Auto Lock", color: .purple)
                    }
                    
                    Toggle(isOn: Binding(
                        get: { BiometricAuthManager.shared.isBiometricEnabled },
                        set: { newValue in toggleBiometrics(enable: newValue) }
                    )) {
                        settingsRow(icon: BiometricAuthManager.shared.biometricType == .faceID ? "faceid" : "touchid", title: "Face ID / Touch ID", color: .blue)
                    }
                    .disabled(!BiometricAuthManager.shared.canUseBiometric)
                }
                
                // Network section
                Section("Network") {
                    NavigationLink(destination: CustomRPCView()) {
                        settingsRow(icon: "network", title: "Custom RPC", color: .teal)
                    }
                    NavigationLink(destination: CustomTestnetView()) {
                        settingsRow(icon: "testtube.2", title: "Custom Testnet", color: .indigo)
                    }
                    Toggle(isOn: $prefManager.showTestnet) {
                        settingsRow(icon: "eye", title: "Show Testnet", color: .gray)
                    }
                }
                
                // DApp section
                Section("DApp") {
                    NavigationLink(destination: ConnectedSitesView()) {
                        settingsRow(icon: "globe", title: "Connected Sites", color: .cyan)
                    }
                    NavigationLink(destination: WalletConnectView()) {
                        settingsRow(icon: "link.circle", title: "WalletConnect", color: .blue)
                    }
                }
                
                // Features section
                Section("Features") {
                    NavigationLink(destination: NFTView()) {
                        settingsRow(icon: "photo.stack.fill", title: "NFT Gallery", color: .pink)
                    }
                    NavigationLink(destination: LendingView()) {
                        settingsRow(icon: "building.columns", title: "Lending", color: .purple)
                    }
                    NavigationLink(destination: PerpsView()) {
                        settingsRow(icon: "chart.line.uptrend.xyaxis", title: "Perps Trading", color: .orange)
                    }
                    NavigationLink(destination: GasAccountView()) {
                        settingsRow(icon: "fuelpump.fill", title: "Gas Account", color: .teal)
                    }
                    NavigationLink(destination: BridgeView()) {
                        settingsRow(icon: "arrow.left.arrow.right.circle", title: "Bridge", color: .indigo)
                    }
                    NavigationLink(destination: RabbyPointsView()) {
                        settingsRow(icon: "star.circle.fill", title: "Rabby Points", color: .orange)
                    }
                    NavigationLink(destination: TokenApprovalView()) {
                        settingsRow(icon: "checkmark.shield", title: "Token Approvals", color: .green)
                    }
                    NavigationLink(destination: NFTApprovalView()) {
                        settingsRow(icon: "photo.badge.checkmark", title: "NFT Approvals", color: .pink)
                    }
                    NavigationLink(destination: SignedTextHistoryView()) {
                        settingsRow(icon: "signature", title: "Signed Messages", color: .gray)
                    }
                    NavigationLink(destination: ChainListView()) {
                        settingsRow(icon: "link.circle.fill", title: "Chain List", color: .blue)
                    }
                }
                
                // Appearance section
                Section("Appearance") {
                    Picker(selection: Binding(
                        get: { prefManager.themeMode },
                        set: { prefManager.setTheme($0) }
                    )) {
                        Text("Light").tag(PreferenceManager.ThemeMode.light)
                        Text("Dark").tag(PreferenceManager.ThemeMode.dark)
                        Text("System").tag(PreferenceManager.ThemeMode.system)
                    } label: {
                        settingsRow(icon: "circle.lefthalf.filled", title: "Theme", color: .gray)
                    }
                    
                    Picker(selection: $prefManager.locale) {
                        Text("English").tag("en")
                        Text("中文").tag("zh-CN")
                        Text("日本語").tag("ja")
                        Text("한국어").tag("ko")
                    } label: {
                        settingsRow(icon: "globe", title: "Language", color: .blue)
                    }
                    
                    Picker(selection: $prefManager.currency) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("CNY").tag("CNY")
                        Text("JPY").tag("JPY")
                    } label: {
                        settingsRow(icon: "dollarsign.circle", title: "Currency", color: .green)
                    }
                }
                
                // About section
                Section("About") {
                    HStack {
                        settingsRow(icon: "info.circle", title: "Version", color: .gray)
                        Spacer()
                        Text("0.93.77").foregroundColor(.secondary)
                    }
                    NavigationLink(destination: AdvancedSettingsView()) {
                        settingsRow(icon: "wrench.and.screwdriver", title: "Advanced", color: .gray)
                    }
                }
                
                // Lock button
                Section {
                    Button(action: lockWallet) {
                        HStack {
                            Spacer()
                            Text("Lock Wallet").foregroundColor(.red).fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .accessibilityLabel("Lock Wallet")
                    .accessibilityHint("Locks the wallet and requires authentication to access")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Biometric Error", isPresented: $showBiometricError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(biometricErrorMessage)
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
            // Enable biometrics: verify with biometric prompt first, then save password
            Task {
                do {
                    let success = try await BiometricAuthManager.shared.authenticate(
                        reason: "Enable biometric unlock for Rabby Wallet"
                    )
                    if success {
                        // Need the current password to save for biometric unlock
                        // For now, enable the flag. In production, show password prompt.
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
}

/// Address Management View
struct AddressManagementView: View {
    @StateObject private var prefManager = PreferenceManager.shared
    
    var body: some View {
        List {
            Section("Active Addresses") {
                ForEach(prefManager.accounts.filter { account in
                    !prefManager.hiddenAddresses.contains(where: { $0.address == account.address })
                }) { account in
                    addressRow(account: account)
                }
            }
            
            if !prefManager.hiddenAddresses.isEmpty {
                Section("Hidden Addresses") {
                    ForEach(prefManager.hiddenAddresses) { account in
                        addressRow(account: account, isHidden: true)
                    }
                }
            }
        }
        .navigationTitle("Addresses")
    }
    
    private func addressRow(account: PreferenceManager.Account, isHidden: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.aliasName ?? account.brandName).fontWeight(.medium)
                Text(String(account.address.prefix(8)) + "..." + String(account.address.suffix(6)))
                    .font(.caption).foregroundColor(.secondary).font(.system(.caption, design: .monospaced))
            }
            Spacer()
            if let balance = account.balance {
                Text("$\(String(format: "%.2f", balance))").font(.subheadline).foregroundColor(.secondary)
            }
        }
        .swipeActions {
            if isHidden {
                Button("Unhide") { prefManager.unhideAddress(account.address) }
                    .tint(.blue)
            } else {
                Button("Hide") { prefManager.hideAddress(account.address) }
                    .tint(.orange)
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
                Text("Never share your seed phrase or private key with anyone. Store it securely offline.")
                    .font(.subheadline).foregroundColor(.red)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Password input
            SecureField("Enter password to reveal", text: $password)
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
                    Text("Show Seed Phrase")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                }
                
                Button(action: revealPrivateKey) {
                    Text("Show Private Key")
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
        .navigationTitle("Backup")
        .onDisappear { clearRevealedData() }
        .alert("Screenshot Detected", isPresented: $showScreenshotWarning) {
            Button("I Understand", role: .cancel) {}
        } message: {
            Text("Be careful! Screenshots of seed phrases and private keys can be a security risk.")
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

/// Token Approval View
struct TokenApprovalView: View {
    @State private var approvals: [TokenApproval] = []
    @State private var isLoading = false
    
    struct TokenApproval: Identifiable {
        let id: String
        let tokenSymbol: String
        let tokenAddress: String
        let spender: String
        let spenderName: String?
        let allowance: String
        let chain: String
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading approvals...")
                } else if approvals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield").font(.system(size: 40)).foregroundColor(.green)
                        Text("No active approvals").foregroundColor(.secondary)
                    }
                } else {
                    List(approvals) { approval in
                        approvalRow(approval: approval)
                    }.listStyle(.plain)
                }
            }
            .navigationTitle("Token Approvals")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func approvalRow(approval: TokenApproval) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(approval.tokenSymbol).fontWeight(.medium)
                Text("Spender: \(approval.spenderName ?? String(approval.spender.prefix(10)) + "...")")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(approval.allowance == "unlimited" ? "Unlimited" : approval.allowance)
                    .font(.subheadline)
                    .foregroundColor(approval.allowance == "unlimited" ? .red : .primary)
                Button("Revoke") { revokeApproval(approval) }
                    .font(.caption).foregroundColor(.red)
            }
        }
    }
    
    private func revokeApproval(_ approval: TokenApproval) {
        // Revoke by setting allowance to 0
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
        .navigationTitle("Security Rules")
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

/// Connected Sites View
struct ConnectedSitesView: View {
    @StateObject private var permManager = DAppPermissionManager.shared
    
    var body: some View {
        Group {
            if permManager.connectedSites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "globe").font(.system(size: 40)).foregroundColor(.gray)
                    Text("No connected sites").foregroundColor(.secondary)
                }
            } else {
                List(permManager.connectedSites) { site in
                    HStack {
                        if let icon = site.icon, let url = URL(string: icon) {
                            AsyncImage(url: url) { image in
                                image.resizable().frame(width: 32, height: 32).cornerRadius(8)
                            } placeholder: { Color.gray.frame(width: 32, height: 32).cornerRadius(8) }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.name).fontWeight(.medium)
                            Text(site.origin).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if site.isConnected {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                        }
                    }
                    .swipeActions {
                        Button("Disconnect") { permManager.disconnectSite(origin: site.origin) }
                            .tint(.red)
                    }
                }.listStyle(.plain)
            }
        }
        .navigationTitle("Connected Sites")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !permManager.connectedSites.isEmpty {
                    Button("Disconnect All") { permManager.disconnectAll() }
                        .foregroundColor(.red)
                }
            }
        }
    }
}

/// Custom RPC View
struct CustomRPCView: View {
    @StateObject private var rpcManager = CustomRPCManager.shared
    @State private var chainName = ""
    @State private var rpcUrl = ""
    
    var body: some View {
        List {
            Section("Add Custom RPC") {
                TextField("Chain Name", text: $chainName)
                TextField("RPC URL", text: $rpcUrl)
                    .keyboardType(.URL).autocapitalization(.none)
                Button("Add") { addRPC() }.disabled(chainName.isEmpty || rpcUrl.isEmpty)
            }
            
            Section("Custom RPCs") {
                ForEach(Array(rpcManager.customRPCs.keys.sorted()), id: \.self) { key in
                    if let config = rpcManager.customRPCs[key] {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(key).fontWeight(.medium)
                                Text(config.url).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if let latency = config.latency {
                                Text("\(latency)ms").font(.caption)
                                    .foregroundColor(latency < 500 ? .green : latency < 1000 ? .orange : .red)
                            }
                            Toggle("", isOn: Binding(
                                get: { config.enable },
                                set: { rpcManager.setRPCEnable(chain: key, enable: $0) }
                            )).labelsHidden()
                        }
                    }
                }
                .onDelete { indexSet in
                    let keys = Array(rpcManager.customRPCs.keys.sorted())
                    indexSet.forEach { rpcManager.removeRPC(chain: keys[$0]) }
                }
            }
        }
        .navigationTitle("Custom RPC")
    }
    
    private func addRPC() {
        rpcManager.setRPC(chain: chainName, url: rpcUrl)
        chainName = ""; rpcUrl = ""
    }
}

/// Custom Testnet View
struct CustomTestnetView: View {
    @StateObject private var testnetManager = CustomTestnetManager.shared
    @State private var showAddForm = false
    
    var body: some View {
        List {
            if testnetManager.testnets.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Text("No custom testnets").foregroundColor(.secondary)
                        Button("Add Testnet") { showAddForm = true }
                    }.frame(maxWidth: .infinity)
                }
            } else {
                ForEach(testnetManager.testnets) { testnet in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(testnet.name).fontWeight(.medium)
                            Text("Chain ID: \(testnet.id)").font(.caption).foregroundColor(.secondary)
                            Text(testnet.rpcUrl).font(.caption2).foregroundColor(.gray)
                        }
                        Spacer()
                        Text(testnet.nativeTokenSymbol).font(.caption).foregroundColor(.blue)
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { testnetManager.removeTestnet(chainId: testnetManager.testnets[$0].id) }
                }
            }
        }
        .navigationTitle("Custom Testnets")
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
                TextField("Chain ID", text: $chainId).keyboardType(.numberPad)
                TextField("Chain Name", text: $name)
                TextField("Native Token Symbol", text: $symbol)
                TextField("RPC URL", text: $rpcUrl).keyboardType(.URL).autocapitalization(.none)
                TextField("Block Explorer URL (optional)", text: $scanLink).keyboardType(.URL).autocapitalization(.none)
                
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
            .navigationTitle("Add Testnet")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
    
    private func addTestnet() {
        guard let id = Int(chainId) else { errorMessage = "Invalid Chain ID"; return }
        isAdding = true; errorMessage = nil
        Task {
            do {
                try await CustomTestnetManager.shared.addTestnet(
                    chainId: id, name: name, nativeTokenSymbol: symbol,
                    rpcUrl: rpcUrl, scanLink: scanLink.isEmpty ? nil : scanLink
                )
                dismiss()
            } catch { errorMessage = error.localizedDescription }
            isAdding = false
        }
    }
}
