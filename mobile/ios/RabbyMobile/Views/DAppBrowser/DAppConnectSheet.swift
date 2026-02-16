import SwiftUI

/// DApp Connect Authorization Sheet - Half-screen sheet for DApp connection approval
/// Corresponds to: src/ui/views/Approval/ (connect type)
/// Displays DApp info, requested permissions, security check results,
/// account selection, and connect/reject actions.
struct DAppConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var securityEngine = SecurityEngineManager.shared
    @StateObject private var permManager = DAppPermissionManager.shared

    // MARK: - Input Properties

    let dappUrl: String
    let dappName: String?
    let dappIcon: String?
    let requestedPermissions: [String]
    let onConnect: (String) -> Void  // Returns the selected account address
    let onReject: () -> Void

    // MARK: - State

    @State private var selectedAddress: String = ""
    @State private var rememberChoice: Bool = false
    @State private var availableAccounts: [Account] = []
    @State private var showAccountPicker: Bool = false
    @State private var securityLevel: SecurityLevel = .unknown
    @State private var securityMessages: [String] = []
    @State private var isCheckingSecurity: Bool = true
    @State private var isFirstConnection: Bool = true

    // MARK: - Security Level

    enum SecurityLevel: String {
        case safe
        case warning
        case danger
        case unknown

        var color: Color {
            switch self {
            case .safe: return .green
            case .warning: return .orange
            case .danger: return .red
            case .unknown: return .gray
            }
        }

        var icon: String {
            switch self {
            case .safe: return "checkmark.shield.fill"
            case .warning: return "exclamationmark.shield.fill"
            case .danger: return "xmark.shield.fill"
            case .unknown: return "shield.fill"
            }
        }

        var titleKey: String {
            switch self {
            case .safe: return "safe"
            case .warning: return "warning"
            case .danger: return "danger"
            case .unknown: return "checking"
            }
        }
    }

    // MARK: - Computed Properties

    private var displayName: String {
        if let name = dappName, !name.isEmpty {
            return name
        }
        return hostFromUrl(dappUrl)
    }

    private var displayHost: String {
        return hostFromUrl(dappUrl)
    }

    private var currentAccountAlias: String {
        if let account = availableAccounts.first(where: { $0.address.lowercased() == selectedAddress.lowercased() }) {
            return account.alianName ?? account.type.rawValue
        }
        return LocalizationManager.shared.t("unknown")
    }

    private var currentAccountBalance: String {
        if let account = availableAccounts.first(where: { $0.address.lowercased() == selectedAddress.lowercased() }) {
            return account.balance ?? "0.00"
        }
        return "0.00"
    }

    private var abbreviatedAddress: String {
        guard selectedAddress.count > 10 else { return selectedAddress }
        let prefix = selectedAddress.prefix(6)
        let suffix = selectedAddress.suffix(4)
        return "\(prefix)...\(suffix)"
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // DApp info section
                    dappInfoSection

                    Divider()

                    // Permissions section
                    permissionsSection

                    Divider()

                    // Security info section
                    securitySection

                    Divider()

                    // Account selection section
                    accountSection

                    // Remember choice toggle
                    rememberChoiceToggle

                    // Action buttons
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(L("Connection Request"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        onReject()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .modifier(SheetPresentationModifier(detents: [.medium, .large], showDragIndicator: true))
        .onAppear {
            initializeState()
        }
        .sheet(isPresented: $showAccountPicker) {
            accountPickerSheet
        }
    }

    // MARK: - DApp Info Section

    private var dappInfoSection: some View {
        VStack(spacing: 12) {
            // DApp favicon
            ZStack {
                if let iconUrl = dappIcon, let url = URL(string: iconUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            dappPlaceholderIcon
                        case .empty:
                            ProgressView()
                                .frame(width: 56, height: 56)
                        @unknown default:
                            dappPlaceholderIcon
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    dappPlaceholderIcon
                }

                // Connection status indicator
                Circle()
                    .fill(isFirstConnection ? Color.blue : Color.green)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .offset(x: 22, y: 22)
            }

            // DApp name
            Text(displayName)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)

            // DApp URL
            Text(displayHost)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            // First connection vs reconnection badge
            if isFirstConnection {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                    Text(L("First time connecting"))
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text(L("Previously connected"))
                        .font(.caption)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    private var dappPlaceholderIcon: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.1))
            .frame(width: 56, height: 56)
            .overlay(
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            )
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("This site wants to:"))
                .font(.headline)
                .foregroundColor(.primary)

            let permissions = effectivePermissions
            ForEach(permissions, id: \.self) { permission in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.body)

                    Text(permission)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var effectivePermissions: [String] {
        if requestedPermissions.isEmpty {
            return [
                LocalizationManager.shared.t("View your wallet address"),
                LocalizationManager.shared.t("Request approval for transactions"),
                LocalizationManager.shared.t("Suggest token additions")
            ]
        }
        return requestedPermissions
    }

    // MARK: - Security Section

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Security Check"))
                    .font(.headline)

                Spacer()

                if isCheckingSecurity {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    securityBadge
                }
            }

            if !securityMessages.isEmpty {
                ForEach(securityMessages, id: \.self) { message in
                    HStack(spacing: 8) {
                        Image(systemName: securityLevel == .danger ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .foregroundColor(securityLevel.color)
                            .font(.caption)

                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var securityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: securityLevel.icon)
                .font(.caption)
            Text(L(securityLevel.titleKey))
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(securityLevel.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(securityLevel.color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Connect with"))
                .font(.headline)

            Button(action: { showAccountPicker = true }) {
                HStack(spacing: 12) {
                    // Account avatar
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                                .font(.body)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(currentAccountAlias)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text(abbreviatedAddress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }

                        Text(LocalizationManager.shared.t("ios.dapp.balanceETH", args: ["balance": currentAccountBalance]))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Remember Choice Toggle

    private var rememberChoiceToggle: some View {
        Button(action: { rememberChoice.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: rememberChoice ? "checkmark.square.fill" : "square")
                    .foregroundColor(rememberChoice ? .blue : .secondary)
                    .font(.body)

                Text(L("Remember my choice"))
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button(action: {
                onReject()
                dismiss()
            }) {
                Text(L("Cancel"))
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Connect button
            Button(action: handleConnect) {
                Text(L("Connect"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(connectButtonDisabled ? Color.blue.opacity(0.4) : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(connectButtonDisabled)
        }
        .padding(.top, 4)
    }

    private var connectButtonDisabled: Bool {
        return selectedAddress.isEmpty || securityLevel == .danger
    }

    // MARK: - Account Picker Sheet

    private var accountPickerSheet: some View {
        NavigationView {
            List {
                ForEach(availableAccounts, id: \.address) { account in
                    Button(action: {
                        selectedAddress = account.address
                        showAccountPicker = false
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(account.alianName ?? account.type.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }

                                Text(abbreviate(account.address))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(LocalizationManager.shared.t("ios.dapp.balanceValue", args: ["balance": account.balance ?? "0.00"]))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if account.address.lowercased() == selectedAddress.lowercased() {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(L("Select Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { showAccountPicker = false }
                }
            }
        }
        .modifier(SheetPresentationModifier(detents: [.medium]))
    }

    // MARK: - Actions

    private func handleConnect() {
        guard !selectedAddress.isEmpty else { return }

        // Save to connected sites via DAppPermissionManager
        let origin = normalizedOrigin(from: dappUrl)
        let accountInfo = DAppPermissionManager.ConnectedSite.AccountInfo(
            address: selectedAddress,
            type: keyringManager.currentAccount?.type.rawValue ?? "Unknown",
            brandName: keyringManager.currentAccount?.brandName ?? "Unknown"
        )

        let chain = ChainManager.shared.selectedChain?.serverId ?? "eth"
        permManager.addSite(
            origin: origin,
            name: displayName,
            icon: dappIcon,
            chain: chain,
            account: accountInfo
        )

        // If rememberChoice is true, add to origin whitelist for auto-connect
        if rememberChoice {
            securityEngine.addOriginToWhitelist(origin.lowercased())
            // Persist the auto-connect preference
            StorageManager.shared.setBool(true, forKey: "autoConnect_\(origin)")
            StorageManager.shared.setString(selectedAddress, forKey: "autoConnectAddr_\(origin)")
        }

        onConnect(selectedAddress)
        dismiss()
    }

    private func initializeState() {
        // Load available accounts
        Task {
            let addresses = await keyringManager.getAccounts()
            var accounts: [Account] = []
            for address in addresses {
                // Try to find matching keyring type
                var keyringType: KeyringType = .hdKeyring
                for keyring in keyringManager.keyrings {
                    let keyringAccounts = await keyring.getAccounts()
                    if keyringAccounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                        keyringType = keyring.type
                        break
                    }
                }
                accounts.append(Account(
                    address: address,
                    type: keyringType,
                    brandName: keyringType.rawValue,
                    alianName: nil,
                    balance: nil
                ))
            }

            await MainActor.run {
                availableAccounts = accounts

                // Default to current account or first available
                if let current = keyringManager.currentAccount {
                    selectedAddress = current.address
                } else if let first = accounts.first {
                    selectedAddress = first.address
                }

                // Check if this is a first-time connection
                let origin = normalizedOrigin(from: dappUrl)
                isFirstConnection = !permManager.isConnected(origin: origin)
                    && permManager.getSite(origin: origin) == nil

                // Check auto-connect preference
                if !isFirstConnection {
                    let host = hostFromUrl(dappUrl)
                    let autoConnect = StorageManager.shared.getBool(forKey: "autoConnect_\(origin)")
                        || StorageManager.shared.getBool(forKey: "autoConnect_\(host)")
                    if autoConnect {
                        // Retrieve the previously selected address
                        if let savedAddr = StorageManager.shared.getString(forKey: "autoConnectAddr_\(origin)")
                            ?? StorageManager.shared.getString(forKey: "autoConnectAddr_\(host)") {
                            selectedAddress = savedAddr
                        }
                        rememberChoice = true
                    }
                }
            }
        }

        // Run security checks
        performSecurityCheck()
    }

    private func performSecurityCheck() {
        Task {
            let origin = normalizedOrigin(from: dappUrl)
            let host = hostFromUrl(dappUrl)
            var messages: [String] = []
            var level: SecurityLevel = .safe

            // Check 1: Is the origin in the blacklist?
            if securityEngine.userData.originBlacklist.contains(origin.lowercased())
                || securityEngine.userData.originBlacklist.contains(host.lowercased()) {
                level = .danger
                messages.append(LocalizationManager.shared.t("This site is in your blacklist."))
            }

            // Check 2: Is this origin whitelisted?
            let isWhitelisted = securityEngine.userData.originWhitelist.contains(origin.lowercased())
                || securityEngine.userData.originWhitelist.contains(host.lowercased())
            if isWhitelisted {
                messages.append(LocalizationManager.shared.t("This site is in your whitelist."))
            }

            // Check 3: Known phishing check via API (best effort)
            do {
                let isPhishing = try await checkPhishingSite(origin: host)
                if isPhishing {
                    level = .danger
                    messages.append(LocalizationManager.shared.t("WARNING: This site has been flagged as a phishing site."))
                }
            } catch {
                // API unavailable - not a blocking issue
            }

            // Check 3.5: Extension-compatible origin rule set (best effort)
            if !selectedAddress.isEmpty {
                if let resp = await securityEngine.checkOrigin(address: selectedAddress, origin: origin) {
                    if !resp.alert.isEmpty {
                        messages.append(resp.alert)
                    }
                    // Escalate level based on decision.
                    switch resp.decision {
                    case .forbidden, .danger:
                        level = .danger
                    case .warning:
                        if level == .safe { level = .warning }
                    case .pass, .loading, .pending:
                        break
                    }
                    // Append rule item alerts (keep short, avoid duplicates).
                    let items = resp.forbidden_list + resp.danger_list + resp.warning_list
                    for item in items.prefix(5) {
                        if !item.alert.isEmpty, !messages.contains(item.alert) {
                            messages.append(item.alert)
                        }
                    }
                }
            }

            // Check 4: First-time connection warning
            if isFirstConnection && level != .danger {
                if level == .safe && !isWhitelisted {
                    level = .warning
                }
                messages.append(LocalizationManager.shared.t("This is your first time connecting to this site."))
            }

            // Check 5: Domain age / reputation (if available)
            do {
                let reputation = try await checkDomainReputation(origin: host)
                if let rep = reputation {
                    messages.append(rep)
                }
            } catch {
                // Non-critical: skip
            }

            // If no issues found and not first connection
            if messages.isEmpty {
                messages.append(LocalizationManager.shared.t("No security issues detected."))
            }

            await MainActor.run {
                securityLevel = level
                securityMessages = messages
                isCheckingSecurity = false
            }
        }
    }

    // MARK: - Security API Helpers

    /// Check if the origin is a known phishing site via Rabby API
    private func checkPhishingSite(origin: String) async throws -> Bool {
        let response = try await OpenAPIService.shared.checkOrigin(origin: origin)
        return response.is_phishing ?? false
    }

    /// Fetch domain reputation/age information from Rabby API
    private func checkDomainReputation(origin: String) async throws -> String? {
        let response = try await OpenAPIService.shared.getDomainInfo(origin: origin)

        var info: [String] = []
        if let ageDays = response.age_days {
            if ageDays < 30 {
                info.append(LocalizationManager.shared.t("ios.dapp.domainAge", args: ["days": "\(ageDays)"]))
            } else {
                info.append(LocalizationManager.shared.t("ios.dapp.domainAgeOk", args: ["days": "\(ageDays)"]))
            }
        }
        if let score = response.reputation_score {
            let scoreText = String(format: "%.0f", score * 100)
            info.append(LocalizationManager.shared.t("ios.dapp.reputationScore", args: ["score": scoreText]))
        }
        return info.isEmpty ? nil : info.joined(separator: " ")
    }

    // MARK: - Helpers

    private func normalizedOrigin(from urlString: String) -> String {
        var candidate = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !candidate.hasPrefix("http://") && !candidate.hasPrefix("https://") {
            candidate = "https://\(candidate)"
        }

        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased() else {
            return hostFromUrl(urlString).lowercased()
        }

        var origin = "\(scheme)://\(host)"
        if let port = components.port {
            let isDefaultPort = (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
            if !isDefaultPort {
                origin += ":\(port)"
            }
        }
        return origin
    }

    private func hostFromUrl(_ urlString: String) -> String {
        if let url = URL(string: urlString), let host = url.host {
            return host
        }
        // Fallback: strip protocol prefix
        var cleaned = urlString
        if cleaned.hasPrefix("https://") { cleaned = String(cleaned.dropFirst(8)) }
        if cleaned.hasPrefix("http://") { cleaned = String(cleaned.dropFirst(7)) }
        if let slashIndex = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[cleaned.startIndex..<slashIndex])
        }
        return cleaned
    }

    private func abbreviate(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Auto-Connect Helper

extension DAppConnectSheet {
    /// Check if a DApp should be automatically connected (remembered choice).
    /// Call this before presenting the sheet to decide if the sheet is needed.
    /// - Parameters:
    ///   - dappUrl: The DApp URL to check
    /// - Returns: The saved address if auto-connect is enabled, nil otherwise
    @MainActor
    static func autoConnectAddress(for dappUrl: String) async -> String? {
        let origin = extractOrigin(from: dappUrl)
        let host = extractHost(from: dappUrl)
        let autoConnect = StorageManager.shared.getBool(forKey: "autoConnect_\(origin)")
            || StorageManager.shared.getBool(forKey: "autoConnect_\(host)")
        guard autoConnect else { return nil }

        // Access Main Actor isolated property safely
        let permManager = DAppPermissionManager.shared
        guard permManager.isConnected(origin: origin) || permManager.isConnected(origin: host) else { return nil }
        return StorageManager.shared.getString(forKey: "autoConnectAddr_\(origin)")
            ?? StorageManager.shared.getString(forKey: "autoConnectAddr_\(host)")
    }

    private static func extractOrigin(from urlString: String) -> String {
        var candidate = urlString
        if !candidate.hasPrefix("http://") && !candidate.hasPrefix("https://") {
            candidate = "https://\(candidate)"
        }
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased() else {
            return extractHost(from: urlString).lowercased()
        }

        var origin = "\(scheme)://\(host)"
        if let port = components.port {
            let isDefaultPort = (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
            if !isDefaultPort {
                origin += ":\(port)"
            }
        }
        return origin
    }

    private static func extractHost(from urlString: String) -> String {
        if let url = URL(string: urlString), let host = url.host {
            return host
        }
        var cleaned = urlString
        if cleaned.hasPrefix("https://") { cleaned = String(cleaned.dropFirst(8)) }
        if cleaned.hasPrefix("http://") { cleaned = String(cleaned.dropFirst(7)) }
        if let slashIndex = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[cleaned.startIndex..<slashIndex])
        }
        return cleaned
    }
}
