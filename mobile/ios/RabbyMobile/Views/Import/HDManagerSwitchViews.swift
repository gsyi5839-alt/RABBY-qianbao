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
    
    var body: some View {
        NavigationView {
            List {
                ForEach(prefManager.accounts) { account in
                    Button(action: {
                        switchTo(account)
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(account.address.dropFirst(2).prefix(2)))
                                        .font(.caption2).fontWeight(.bold).foregroundColor(.blue)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.aliasName ?? account.brandName)
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("\(account.address.prefix(8))...\(account.address.suffix(6))")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if account.address.lowercased() == prefManager.currentAccount?.address.lowercased() {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            
                            if let balance = account.balance {
                                Text("$\(String(format: "%.2f", balance))")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(L("Switch Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { isPresented = false }
                }
            }
        }
    }
    
    private func switchTo(_ account: PreferenceManager.Account) {
        prefManager.setCurrentAccount(account)
        isPresented = false
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
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(chain.symbol.prefix(2)))
                            .font(.caption2).fontWeight(.bold).foregroundColor(.purple)
                    )
                
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
