import SwiftUI

/// HD Manager View - HD wallet derivation path management
/// Corresponds to: src/ui/views/HDManager/
/// Allows managing HD wallet address derivation with custom BIP44 paths
struct HDManagerView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var hdPath = "m/44'/60'/0'/0"
    @State private var addressType: AddressType = .bip44
    @State private var derivedAddresses: [HDAddress] = []
    @State private var selectedAddresses: Set<String> = []
    @State private var isLoading = false
    @State private var isImporting = false
    @State private var currentPage = 0
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    let mnemonic: String
    let password: String?
    var onComplete: (([String]) -> Void)?
    
    enum AddressType: String, CaseIterable {
        case bip44 = "BIP44"
        case ledgerLive = "Ledger Live"
        case legacy = "Legacy"
        
        var path: String {
            switch self {
            case .bip44: return "m/44'/60'/0'/0"
            case .ledgerLive: return "m/44'/60'/0'"
            case .legacy: return "m/44'/60'/0'/0"
            }
        }
    }
    
    struct HDAddress: Identifiable {
        let id: String
        let index: Int
        let address: String
        var balance: String?
        var txCount: Int?
        var isImported: Bool
        
        var shortAddress: String {
            guard address.count > 12 else { return address }
            return "\(address.prefix(8))...\(address.suffix(6))"
        }
        
        var fullPath: String {
            return "m/44'/60'/0'/0/\(index)"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Address type selector
                addressTypeSelector
                
                // Current path display
                pathDisplay
                
                // Address list
                if isLoading && derivedAddresses.isEmpty {
                    Spacer()
                    ProgressView(L("Deriving addresses..."))
                    Spacer()
                } else {
                    addressList
                }
                
                // Bottom action bar
                bottomBar
            }
            .navigationTitle(L("Manage HD Wallet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Close")) { dismiss() }
                }
            }
            .onAppear { loadAddresses() }
        }
    }
    
    // MARK: - Subviews
    
    private var addressTypeSelector: some View {
        Picker(L("Address Type"), selection: $addressType) {
            ForEach(AddressType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .onChange(of: addressType) { _ in
            hdPath = addressType.path
            currentPage = 0
            derivedAddresses = []
            loadAddresses()
        }
    }
    
    private var pathDisplay: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Derivation Path"))
                    .font(.caption).foregroundColor(.secondary)
                Text(hdPath)
                    .font(.system(.subheadline, design: .monospaced))
            }
            
            Spacer()
            
            Text("Page \(currentPage + 1)")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var addressList: some View {
        List {
            ForEach(derivedAddresses) { addr in
                HStack(spacing: 12) {
                    // Selection
                    if addr.isImported {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: selectedAddresses.contains(addr.address) ?
                              "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedAddresses.contains(addr.address) ? .blue : .gray)
                    }
                    
                    // Index & Path
                    VStack(alignment: .leading, spacing: 2) {
                        Text(addr.shortAddress)
                            .font(.system(.subheadline, design: .monospaced))
                        Text(addr.fullPath)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Balance & TX count
                    VStack(alignment: .trailing, spacing: 2) {
                        if let balance = addr.balance {
                            Text(balance)
                                .font(.caption).foregroundColor(.primary)
                        }
                        if let txCount = addr.txCount, txCount > 0 {
                            Text("\(txCount) txs")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    
                    if addr.isImported {
                        Text(L("Imported"))
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green).cornerRadius(4)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !addr.isImported else { return }
                    if selectedAddresses.contains(addr.address) {
                        selectedAddresses.remove(addr.address)
                    } else {
                        selectedAddresses.insert(addr.address)
                    }
                }
                .opacity(addr.isImported ? 0.7 : 1.0)
            }
        }
        .listStyle(.plain)
    }
    
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Pagination
            HStack {
                Button(action: prevPage) {
                    Image(systemName: "chevron.left")
                        .padding(8).background(Color(.systemGray5)).cornerRadius(8)
                }
                .disabled(currentPage == 0)
                
                Spacer()
                
                Text("Addresses \(currentPage * 5 + 1)-\(currentPage * 5 + 5)")
                    .font(.caption).foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: nextPage) {
                    Image(systemName: "chevron.right")
                        .padding(8).background(Color(.systemGray5)).cornerRadius(8)
                }
            }
            
            if let error = errorMessage {
                Text(error).font(.caption).foregroundColor(.red)
            }
            
            // Import button
            Button(action: importSelected) {
                HStack {
                    if isImporting { ProgressView().tint(.white) }
                    Text(isImporting ? "Importing..." : "Import \(selectedAddresses.count) Address(es)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding()
                .background(selectedAddresses.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white).cornerRadius(12)
            }
            .disabled(selectedAddresses.isEmpty || isImporting)
        }
        .padding()
        .background(Color(.systemBackground).shadow(color: .black.opacity(0.05), radius: 4, y: -2))
    }
    
    // MARK: - Actions
    
    private func loadAddresses() {
        isLoading = true
        Task {
            do {
                let existingAddresses = await keyringManager.getAllAddresses()
                let startIndex = currentPage * 5
                let addresses = try await keyringManager.deriveAddresses(
                    mnemonic: mnemonic,
                    hdPath: hdPath,
                    startIndex: startIndex,
                    count: 5
                )
                derivedAddresses = addresses.enumerated().map { (idx, addr) in
                    HDAddress(
                        id: addr, index: startIndex + idx, address: addr,
                        balance: nil, txCount: nil,
                        isImported: existingAddresses.contains(where: { $0.lowercased() == addr.lowercased() })
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func prevPage() {
        guard currentPage > 0 else { return }
        currentPage -= 1
        loadAddresses()
    }
    
    private func nextPage() {
        currentPage += 1
        loadAddresses()
    }
    
    private func importSelected() {
        isImporting = true
        Task {
            do {
                try await keyringManager.importFromMnemonic(
                    mnemonic: mnemonic,
                    password: password,
                    accountCount: selectedAddresses.count
                )
                let imported = Array(selectedAddresses)
                onComplete?(imported)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isImporting = false
        }
    }
}

/// Switch Account Popup - Quick account switching overlay
/// Corresponds to: src/ui/views/CommonPopup/SwitchAddress.tsx
struct SwitchAccountPopup: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var prefManager = PreferenceManager.shared
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var editingAlias: PreferenceManager.Account? = nil
    @State private var aliasText = ""
    @State private var copiedAddress: String? = nil
    @State private var showImport = false
    
    // Group accounts by keyring type
    private var groupedAccounts: [(String, String, [PreferenceManager.Account])] {
        let filtered = filteredAccounts
        var groups: [(String, String, [PreferenceManager.Account])] = []
        
        let hdAccounts = filtered.filter { $0.type == KeyringType.hdKeyring.rawValue }
        let privateKeyAccounts = filtered.filter { $0.type == KeyringType.simpleKeyring.rawValue }
        let watchAccounts = filtered.filter { $0.type == KeyringType.watchAddress.rawValue }
        let otherAccounts = filtered.filter {
            $0.type != KeyringType.hdKeyring.rawValue &&
            $0.type != KeyringType.simpleKeyring.rawValue &&
            $0.type != KeyringType.watchAddress.rawValue
        }
        
        if !hdAccounts.isEmpty {
            groups.append(("seedphrase", "lock.shield", hdAccounts))
        }
        if !privateKeyAccounts.isEmpty {
            groups.append(("key", "key.fill", privateKeyAccounts))
        }
        if !otherAccounts.isEmpty {
            groups.append(("other", "externaldrive.connected.to.line.below", otherAccounts))
        }
        if !watchAccounts.isEmpty {
            groups.append(("watch", "eye.fill", watchAccounts))
        }
        return groups
    }
    
    private var filteredAccounts: [PreferenceManager.Account] {
        guard !searchText.isEmpty else { return prefManager.accounts }
        let q = searchText.lowercased()
        return prefManager.accounts.filter {
            $0.address.lowercased().contains(q) ||
            ($0.aliasName ?? "").lowercased().contains(q) ||
            $0.brandName.lowercased().contains(q)
        }
    }
    
    private func keyringLabel(_ key: String) -> String {
        switch key {
        case "seedphrase": return LocalizationManager.shared.t("Seed Phrase", defaultValue: "Seed Phrase")
        case "key": return LocalizationManager.shared.t("Private Key", defaultValue: "Private Key")
        case "watch": return LocalizationManager.shared.t("Watch Only", defaultValue: "Watch Only")
        default: return LocalizationManager.shared.t("Other", defaultValue: "Other")
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField(L("Search by address or alias"), text: $searchText)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if filteredAccounts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? L("No accounts found") : L("No matching accounts"))
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(groupedAccounts, id: \.0) { (key, icon, accounts) in
                                // Group header
                                HStack(spacing: 6) {
                                    Image(systemName: icon)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(keyringLabel(key))
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Text("(\(accounts.count))")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, 16)
                                .padding(.bottom, 6)
                                
                                ForEach(accounts) { account in
                                    accountRow(account)
                                    if account.id != accounts.last?.id {
                                        Divider().padding(.leading, 64)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
                
                // Bottom actions
                VStack(spacing: 0) {
                    Divider()
                    Button(action: { showImport = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            Text(L("Add New Address"))
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle(L("Switch Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { isPresented = false }
                }
            }
            .task {
                await keyringManager.refreshPreferenceAccounts()
            }
            .sheet(isPresented: $showImport) {
                ImportOptionsView()
            }
            .alert(L("Edit Alias"), isPresented: Binding(
                get: { editingAlias != nil },
                set: { if !$0 { editingAlias = nil } }
            )) {
                TextField(L("Alias"), text: $aliasText)
                Button(L("Save")) {
                    if let account = editingAlias {
                        prefManager.setAlias(address: account.address, alias: aliasText)
                    }
                    editingAlias = nil
                }
                Button(L("Cancel"), role: .cancel) { editingAlias = nil }
            } message: {
                Text(L("Enter a name for this address"))
            }
        }
    }
    
    private func accountRow(_ account: PreferenceManager.Account) -> some View {
        let isCurrent = account.address.lowercased() == keyringManager.currentAccount?.address.lowercased()
        
        return Button(action: { switchTo(account) }) {
            HStack(spacing: 12) {
                // Account avatar with keyring type indicator
                ZStack(alignment: .bottomTrailing) {
                    // Identicon-style colored circle
                    Circle()
                        .fill(isCurrent
                            ? LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color(.systemGray4), Color(.systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(account.address.dropFirst(2).prefix(2)).uppercased())
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(isCurrent ? .white : .secondary)
                        )
                    
                    // Keyring type badge
                    keyringBadge(for: account.type)
                }
                
                // Account info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(account.aliasName ?? account.brandName)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(isCurrent ? .blue : .primary)
                            .lineLimit(1)
                        
                        if isCurrent {
                            Text(L("Current"))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.blue)
                                .cornerRadius(3)
                        }
                    }
                    
                    Text(EthereumUtil.formatAddress(account.address))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Balance
                if let balance = account.balance, balance > 0 {
                    Text("$\(String(format: "%.2f", balance))")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Action buttons
                HStack(spacing: 8) {
                    // Copy address
                    Button(action: { copyAddress(account.address) }) {
                        Image(systemName: copiedAddress == account.address ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(copiedAddress == account.address ? .green : .gray)
                    }
                    .buttonStyle(.plain)
                    
                    // Edit alias
                    Button(action: {
                        aliasText = account.aliasName ?? ""
                        editingAlias = account
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(isCurrent ? Color.blue.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    private func keyringBadge(for type: String) -> some View {
        let (icon, color): (String, Color) = {
            switch type {
            case KeyringType.hdKeyring.rawValue:
                return ("lock.shield.fill", .blue)
            case KeyringType.simpleKeyring.rawValue:
                return ("key.fill", .orange)
            case KeyringType.watchAddress.rawValue:
                return ("eye.fill", .gray)
            default:
                return ("link.circle.fill", .purple)
            }
        }()
        
        return Image(systemName: icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(3)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            .offset(x: 2, y: 2)
    }
    
    private func switchTo(_ account: PreferenceManager.Account) {
        Task {
            do {
                try await keyringManager.selectAccount(address: account.address)
                await MainActor.run {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isPresented = false
                }
            } catch {
                // fallback for legacy data
                prefManager.setCurrentAccount(account)
                if let type = KeyringType(rawValue: account.type) {
                    keyringManager.currentAccount = Account(
                        address: account.address,
                        type: type,
                        brandName: account.brandName,
                        alianName: account.aliasName
                    )
                }
                await MainActor.run {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isPresented = false
                }
            }
        }
    }
    
    private func copyAddress(_ address: String) {
        UIPasteboard.general.string = address
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { copiedAddress = address }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { if copiedAddress == address { copiedAddress = nil } }
        }
    }
}

/// Switch Chain Popup - Quick chain switching overlay
/// Corresponds to: src/ui/views/CommonPopup/SwitchChain.tsx
struct SwitchChainPopup: View {
    @StateObject private var chainManager = ChainManager.shared
    @StateObject private var prefManager = PreferenceManager.shared
    @Binding var isPresented: Bool
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search
                TextField(L("Search chains"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                List {
                    Section(L("Mainnets")) {
                        ForEach(filteredMainnets) { chain in
                            chainRow(chain)
                        }
                    }
                    
                    if prefManager.showTestnet && !filteredTestnets.isEmpty {
                        Section(L("Testnets")) {
                            ForEach(filteredTestnets) { chain in
                                chainRow(chain)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(L("Switch Chain"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { isPresented = false }
                }
            }
        }
    }
    
    private var filteredMainnets: [Chain] {
        if searchText.isEmpty { return chainManager.mainnetChains }
        return chainManager.mainnetChains.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredTestnets: [Chain] {
        if searchText.isEmpty { return chainManager.testnetChains }
        return chainManager.testnetChains.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func chainRow(_ chain: Chain) -> some View {
        Button(action: {
            chainManager.selectChain(chain)
            isPresented = false
        }) {
            HStack(spacing: 12) {
                ChainIconView(chainId: chain.serverId, logoUrl: chain.logo, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chain.name).font(.subheadline).foregroundColor(.primary)
                    Text(chain.symbol).font(.caption).foregroundColor(.secondary)
                }
                
                Spacer()
                
                if chainManager.selectedChain?.id == chain.id {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                }
            }
        }
    }
}
