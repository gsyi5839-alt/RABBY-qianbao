import SwiftUI

/// Address Management - grouped account management with search/sort/switch/delete.
/// Corresponds to extension pages:
/// - src/ui/views/AddressManagement/
/// - src/ui/views/ManageAddress/
struct AddressManagementView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var prefManager = PreferenceManager.shared
    @StateObject private var chainManager = ChainManager.shared

    @State private var sortMode: SortMode = .balance
    @State private var searchText = ""
    @State private var accountToDelete: PreferenceManager.Account?
    @State private var accountToEditAlias: PreferenceManager.Account?
    @State private var aliasDraft = ""
    @State private var showExportKey = false
    @State private var exportedKey = ""
    @State private var errorMessage: String?

    enum SortMode: String, CaseIterable {
        case balance = "Balance"
        case name = "Name"
        case recent = "Recent"
    }

    var body: some View {
        List {
            if !hdAccounts.isEmpty {
                Section {
                    ForEach(hdAccounts) { account in
                        accountRow(account)
                    }
                    Button(action: { addNextHDAccount(hdAccounts.first) }) {
                        Label(L("Add Next Account"), systemImage: "plus.circle")
                    }
                } header: {
                    Label("Seed Phrase", systemImage: "lock.shield")
                }
            }

            if !privateKeyAccounts.isEmpty {
                Section {
                    ForEach(privateKeyAccounts) { account in
                        accountRow(account)
                    }
                } header: {
                    Label("Private Key", systemImage: "key.fill")
                }
            }

            if !otherAccounts.isEmpty {
                Section {
                    ForEach(otherAccounts) { account in
                        accountRow(account)
                    }
                } header: {
                    Label("Other", systemImage: "externaldrive.connected.to.line.below")
                }
            }

            if !watchAccounts.isEmpty {
                Section {
                    ForEach(watchAccounts) { account in
                        accountRow(account)
                    }
                } header: {
                    Label("Watch Only", systemImage: "eye.fill")
                }
            }

            if filteredSortedAccounts.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? L("No accounts found") : L("No matching accounts"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L("Address Management"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: L("Search by address or alias"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        Button(action: { sortMode = mode }) {
                            Label(mode.rawValue, systemImage: sortMode == mode ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .task { await refreshAccounts() }
        .refreshable { await refreshAccounts() }
        .alert(item: $accountToDelete) { account in
            Alert(
                title: Text(L("Delete Account")),
                message: Text(L("Are you sure you want to remove this account? Make sure you have a backup of the private key or seed phrase.")),
                primaryButton: .destructive(Text(L("Delete"))) { deleteAccount(account) },
                secondaryButton: .cancel(Text(L("Cancel")))
            )
        }
        .alert(L("Edit Alias"), isPresented: Binding(
            get: { accountToEditAlias != nil },
            set: { if !$0 { accountToEditAlias = nil } }
        )) {
            TextField(L("Alias"), text: $aliasDraft)
            Button(L("Save")) { saveAlias() }
            Button(L("Cancel"), role: .cancel) { accountToEditAlias = nil }
        } message: {
            Text(L("Enter a name for this address"))
        }
        .alert(L("Private Key"), isPresented: $showExportKey) {
            Button(L("Copy")) { UIPasteboard.general.string = exportedKey }
            Button(L("Close"), role: .cancel) { exportedKey = "" }
        } message: {
            Text(exportedKey)
        }
        .alert(L("Error"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L("OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var filteredSortedAccounts: [PreferenceManager.Account] {
        let filtered: [PreferenceManager.Account]
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = prefManager.accounts
        } else {
            let query = searchText.lowercased()
            filtered = prefManager.accounts.filter {
                $0.address.lowercased().contains(query) ||
                ($0.aliasName ?? "").lowercased().contains(query) ||
                $0.brandName.lowercased().contains(query)
            }
        }

        switch sortMode {
        case .balance:
            return filtered.sorted { ($0.balance ?? 0) > ($1.balance ?? 0) }
        case .name:
            return filtered.sorted {
                displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
            }
        case .recent:
            return filtered.sorted { ($0.index ?? 0) > ($1.index ?? 0) }
        }
    }

    private var hdAccounts: [PreferenceManager.Account] {
        filteredSortedAccounts.filter { $0.type == KeyringType.hdKeyring.rawValue }
    }

    private var privateKeyAccounts: [PreferenceManager.Account] {
        filteredSortedAccounts.filter { $0.type == KeyringType.simpleKeyring.rawValue }
    }

    private var watchAccounts: [PreferenceManager.Account] {
        filteredSortedAccounts.filter { $0.type == KeyringType.watchAddress.rawValue }
    }

    private var otherAccounts: [PreferenceManager.Account] {
        filteredSortedAccounts.filter {
            $0.type != KeyringType.hdKeyring.rawValue &&
            $0.type != KeyringType.simpleKeyring.rawValue &&
            $0.type != KeyringType.watchAddress.rawValue
        }
    }

    private func accountRow(_ account: PreferenceManager.Account) -> some View {
        let isCurrent = account.address.lowercased() == keyringManager.currentAccount?.address.lowercased()

        return HStack(spacing: 12) {
            Circle()
                .fill(colorForAddress(account.address))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(account.address.dropFirst(2).prefix(2)).uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName(for: account))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if isCurrent {
                        Text(L("Current"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                Text(EthereumUtil.formatAddress(account.address))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let balance = account.balance, balance > 0 {
                Text("$\(String(format: "%.2f", balance))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { setPrimary(account) }
        .swipeActions(edge: .trailing) {
            Button(L("Delete"), role: .destructive) {
                accountToDelete = account
            }
        }
        .contextMenu {
            Button(action: { UIPasteboard.general.string = account.address }) {
                Label(L("Copy Address"), systemImage: "doc.on.doc")
            }

            Button(action: { setPrimary(account) }) {
                Label(L("Set as Primary"), systemImage: "star")
            }

            Button(action: {
                aliasDraft = account.aliasName ?? ""
                accountToEditAlias = account
            }) {
                Label(L("Edit Alias"), systemImage: "pencil")
            }

            if account.type == KeyringType.simpleKeyring.rawValue {
                Button(action: { exportPrivateKey(account) }) {
                    Label(L("Export Private Key"), systemImage: "key")
                }
            }

            if let scan = chainManager.selectedChain?.scanUrl,
               let url = URL(string: "\(scan)/address/\(account.address)") {
                Link(destination: url) {
                    Label(L("View on Explorer"), systemImage: "globe")
                }
            }
        }
    }

    private func displayName(for account: PreferenceManager.Account) -> String {
        if let alias = account.aliasName, !alias.isEmpty {
            return alias
        }
        if account.type == KeyringType.hdKeyring.rawValue, let idx = account.index {
            return "Account \(idx + 1)"
        }
        return account.brandName
    }

    private func setPrimary(_ account: PreferenceManager.Account) {
        Task {
            do {
                try await keyringManager.selectAccount(address: account.address)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func addNextHDAccount(_ account: PreferenceManager.Account?) {
        Task {
            do {
                try await keyringManager.addAccountFromExistingMnemonic(address: account?.address ?? "")
                await refreshAccounts()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func deleteAccount(_ account: PreferenceManager.Account) {
        Task {
            do {
                guard let keyringType = KeyringType(rawValue: account.type) else {
                    throw KeyringError.invalidOptions
                }
                try await keyringManager.removeAccount(address: account.address, type: keyringType)
                await refreshAccounts()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func exportPrivateKey(_ account: PreferenceManager.Account) {
        Task {
            do {
                guard let unlockPassword = keyringManager.currentUnlockPassword() else {
                    throw KeyringError.walletLocked
                }
                let key = try await keyringManager.exportPrivateKey(
                    address: account.address,
                    password: unlockPassword
                )
                await MainActor.run {
                    exportedKey = key
                    showExportKey = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func saveAlias() {
        guard let account = accountToEditAlias else { return }
        prefManager.setAlias(
            address: account.address,
            alias: aliasDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if keyringManager.currentAccount?.address.lowercased() == account.address.lowercased() {
            keyringManager.currentAccount?.alianName = aliasDraft
        }
        accountToEditAlias = nil
    }

    private func refreshAccounts() async {
        await keyringManager.refreshPreferenceAccounts()
    }

    private func colorForAddress(_ address: String) -> Color {
        let hash = abs(address.hashValue)
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .teal]
        return colors[hash % colors.count]
    }
}
