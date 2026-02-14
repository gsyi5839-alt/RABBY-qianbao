import SwiftUI

/// Address Management - group/sort/rename/delete accounts
/// Corresponds to: Settings > Address Management
struct AddressManagementView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var sortMode: SortMode = .balance
    @State private var searchText = ""
    @State private var showDeleteConfirm = false
    @State private var addressToDelete: String?
    @State private var showExportKey = false
    @State private var exportedKey = ""

    enum SortMode: String, CaseIterable {
        case balance = "Balance"
        case name = "Name"
        case date = "Date"
    }

    var body: some View {
        NavigationView {
            List {
                // HD Wallets
                if !hdAccounts.isEmpty {
                    Section {
                        ForEach(hdAccounts, id: \.address) { account in
                            addressRow(account)
                                .swipeActions(edge: .trailing) {
                                    Button(L("Delete"), role: .destructive) {
                                        addressToDelete = account.address
                                        showDeleteConfirm = true
                                    }
                                }
                                .contextMenu { contextMenuItems(for: account) }
                        }

                        Button(action: { addNextHDAccount() }) {
                            Label(L("Add Next Account"), systemImage: "plus.circle")
                        }
                    } header: {
                        HStack {
                            Image(systemName: "key.fill")
                            Text(L("HD Wallets"))
                        }
                    }
                }

                // Imported Private Keys
                if !importedAccounts.isEmpty {
                    Section {
                        ForEach(importedAccounts, id: \.address) { account in
                            addressRow(account)
                                .swipeActions(edge: .trailing) {
                                    Button(L("Delete"), role: .destructive) {
                                        addressToDelete = account.address
                                        showDeleteConfirm = true
                                    }
                                }
                                .contextMenu { contextMenuItems(for: account) }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text(L("Imported"))
                        }
                    }
                }

                // Hardware Wallets
                if !hardwareAccounts.isEmpty {
                    Section {
                        ForEach(hardwareAccounts, id: \.address) { account in
                            addressRow(account)
                                .contextMenu { contextMenuItems(for: account) }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                            Text(L("Hardware Wallets"))
                        }
                    }
                }

                // Watch Only
                if !watchOnlyAccounts.isEmpty {
                    Section {
                        ForEach(watchOnlyAccounts, id: \.address) { account in
                            addressRow(account)
                                .swipeActions(edge: .trailing) {
                                    Button(L("Delete"), role: .destructive) {
                                        addressToDelete = account.address
                                        showDeleteConfirm = true
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "eye")
                            Text(L("Watch Only"))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L("Address Management"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search addresses")
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
            .alert(L("Delete Account"), isPresented: $showDeleteConfirm) {
                Button(L("Delete"), role: .destructive) {
                    if let addr = addressToDelete {
                        deleteAccount(addr)
                    }
                }
                Button(L("Cancel"), role: .cancel) {}
            } message: {
                Text(L("Are you sure you want to remove this account? Make sure you have a backup of the private key or seed phrase."))
            }
            .alert(L("Private Key"), isPresented: $showExportKey) {
                Button(L("Copy")) { UIPasteboard.general.string = exportedKey }
                Button(L("Close"), role: .cancel) { exportedKey = "" }
            } message: {
                Text(exportedKey)
            }
        }
    }

    // MARK: - Address Row

    private func addressRow(_ account: AccountInfo) -> some View {
        HStack(spacing: 12) {
            // Identicon placeholder
            Circle()
                .fill(colorForAddress(account.address))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(account.address.suffix(2)))
                        .font(.caption2)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name.isEmpty ? "Account" : account.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(EthereumUtil.truncateAddress(account.address))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if account.type == .hd, let path = account.derivationPath {
                    Text(path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(account.balance)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if account.isPrimary {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
    }

    @ViewBuilder
    private func contextMenuItems(for account: AccountInfo) -> some View {
        Button(action: { UIPasteboard.general.string = account.address }) {
            Label(L("Copy Address"), systemImage: "doc.on.doc")
        }

        Button(action: { setPrimary(account.address) }) {
            Label(L("Set as Primary"), systemImage: "star")
        }

        if account.type == .imported {
            Button(action: { exportPrivateKey(account.address) }) {
                Label(L("Export Private Key"), systemImage: "key")
            }
        }

        if let url = URL(string: "https://etherscan.io/address/\(account.address)") {
            Link(destination: url) {
                Label(L("View on Explorer"), systemImage: "globe")
            }
        }
    }

    // MARK: - Computed Properties

    private var allAccounts: [AccountInfo] {
        // Placeholder - would come from KeyringManager
        return []
    }

    private var hdAccounts: [AccountInfo] { allAccounts.filter { $0.type == .hd } }
    private var importedAccounts: [AccountInfo] { allAccounts.filter { $0.type == .imported } }
    private var hardwareAccounts: [AccountInfo] { allAccounts.filter { $0.type == .hardware } }
    private var watchOnlyAccounts: [AccountInfo] { allAccounts.filter { $0.type == .watchOnly } }

    // MARK: - Actions

    private func addNextHDAccount() {
        Task { try? await keyringManager.addAccountFromExistingMnemonic(address: "") }
    }

    private func deleteAccount(_ address: String) {
        // Look up the account type from our local model
        if let account = allAccounts.first(where: { $0.address.lowercased() == address.lowercased() }) {
            let keyringType: KeyringType
            switch account.type {
            case .hd: keyringType = .hdKeyring
            case .imported: keyringType = .simpleKeyring
            case .hardware: keyringType = .ledger
            case .watchOnly: keyringType = .watchAddress
            }
            Task { try? await keyringManager.removeAccount(address: address, type: keyringType) }
        }
    }

    private func setPrimary(_ address: String) {
        if let account = allAccounts.first(where: { $0.address.lowercased() == address.lowercased() }) {
            let keyringType: KeyringType
            switch account.type {
            case .hd: keyringType = .hdKeyring
            case .imported: keyringType = .simpleKeyring
            case .hardware: keyringType = .ledger
            case .watchOnly: keyringType = .watchAddress
            }
            keyringManager.currentAccount = Account(
                address: address,
                type: keyringType,
                brandName: keyringType.rawValue,
                alianName: account.name
            )
        }
    }

    private func exportPrivateKey(_ address: String) {
        Task {
            if let key = try? await keyringManager.exportPrivateKey(address: address, password: "") {
                await MainActor.run {
                    exportedKey = key
                    showExportKey = true
                }
            }
        }
    }

    private func colorForAddress(_ address: String) -> Color {
        let hash = abs(address.hashValue)
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .teal]
        return colors[hash % colors.count]
    }
}

// MARK: - Account Info Model

struct AccountInfo: Identifiable {
    var id: String { address }
    let address: String
    let name: String
    let type: AccountType
    let balance: String
    let isPrimary: Bool
    let derivationPath: String?

    enum AccountType {
        case hd, imported, hardware, watchOnly
    }
}
