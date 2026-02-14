import SwiftUI

/// Import Options View - Hub for all wallet import methods
/// Corresponds to: src/ui/views/ImportMode.tsx + NewUserImport/
struct ImportOptionsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showMnemonic = false
    @State private var showPrivateKey = false
    @State private var showWatchAddress = false
    @State private var showLedger = false
    @State private var showGnosis = false
    @State private var showWalletConnect = false
    @State private var showJsonKeystore = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Seed Phrase
                    importOptionCard(
                        icon: "key.fill", title: "Seed Phrase",
                        description: "Import with 12 or 24 word mnemonic",
                        color: .blue
                    ) { showMnemonic = true }
                    
                    // Private Key
                    importOptionCard(
                        icon: "lock.fill", title: "Private Key",
                        description: "Import with a private key",
                        color: .purple
                    ) { showPrivateKey = true }
                    
                    // Watch Address
                    importOptionCard(
                        icon: "eye.fill", title: "Watch Mode",
                        description: "Monitor an address without signing ability",
                        color: .green
                    ) { showWatchAddress = true }
                    
                    // JSON Keystore
                    importOptionCard(
                        icon: "doc.fill", title: "JSON Keystore",
                        description: "Import from encrypted JSON keystore file",
                        color: .orange
                    ) { showJsonKeystore = true }
                    
                    Divider().padding(.vertical, 8)
                    
                    Text(L("Hardware Wallets")).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Ledger
                    importOptionCard(
                        icon: "lock.shield.fill", title: "Ledger",
                        description: "Connect via Bluetooth (Nano X / S Plus)",
                        color: .blue
                    ) { showLedger = true }
                    
                    Divider().padding(.vertical, 8)
                    
                    Text(L("Multi-Sig & Others")).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Gnosis Safe
                    importOptionCard(
                        icon: "person.3.fill", title: "Gnosis Safe",
                        description: "Import a Safe multi-signature wallet",
                        color: .teal
                    ) { showGnosis = true }
                    
                    // WalletConnect
                    importOptionCard(
                        icon: "link.circle.fill", title: "WalletConnect",
                        description: "Connect to external wallet via WalletConnect",
                        color: .indigo
                    ) { showWalletConnect = true }
                }
                .padding()
            }
            .navigationTitle(L("Import Wallet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
            }
            .sheet(isPresented: $showMnemonic) { ImportWalletView() }
            .sheet(isPresented: $showPrivateKey) { ImportPrivateKeyView() }
            .sheet(isPresented: $showWatchAddress) { WatchAddressImportView() }
            .sheet(isPresented: $showLedger) { LedgerConnectView() }
            .sheet(isPresented: $showGnosis) { GnosisSafeImportView() }
            .sheet(isPresented: $showWalletConnect) { WalletConnectView() }
            .sheet(isPresented: $showJsonKeystore) { JsonKeystoreImportView() }
        }
    }
    
    private func importOptionCard(icon: String, title: String, description: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3).foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color).cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundColor(.primary)
                    Text(description).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

/// Import Private Key View
/// Corresponds to: src/ui/views/ImportPrivateKey.tsx
struct ImportPrivateKeyView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var privateKey = ""
    @State private var password = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text(L("Never share your private key. Anyone with your key can steal your assets."))
                            .font(.caption).foregroundColor(.orange)
                    }
                    .padding().background(Color.orange.opacity(0.1)).cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Private Key")).font(.headline)
                        SecureField(L("Enter private key (with or without 0x prefix)"), text: $privateKey)
                            .padding().background(Color(.systemGray6)).cornerRadius(8)
                            .autocapitalization(.none)
                    }
                    
                    if !keyringManager.isInitialized {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Password")).font(.headline)
                            SecureField(L("Create a password"), text: $password)
                                .padding().background(Color(.systemGray6)).cornerRadius(8)
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                    
                    Button(action: importKey) {
                        HStack {
                            if isImporting { ProgressView().tint(.white) }
                            Text(isImporting ? "Importing..." : "Import")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(canImport ? Color.blue : Color.gray)
                        .foregroundColor(.white).cornerRadius(12)
                    }
                    .disabled(!canImport || isImporting)
                }
                .padding()
            }
            .navigationTitle(L("Import Private Key"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } } }
            .alert(L("Import Successful"), isPresented: $showSuccess) {
                Button(L("OK")) { dismiss() }
            } message: { Text(L("Your wallet has been imported successfully.")) }
        }
    }
    
    private var canImport: Bool {
        !privateKey.isEmpty && (keyringManager.isInitialized || password.count >= 8)
    }
    
    private func importKey() {
        isImporting = true; errorMessage = nil
        Task {
            do {
                try await keyringManager.importPrivateKey(
                    privateKey: privateKey.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: keyringManager.isInitialized ? nil : password
                )
                showSuccess = true
            } catch { errorMessage = error.localizedDescription }
            isImporting = false
        }
    }
}

/// Watch Address Import View
/// Corresponds to: src/ui/views/ImportWatchAddress.tsx
struct WatchAddressImportView: View {
    @State private var address = ""
    @State private var ensName = ""
    @State private var isResolving = false
    @State private var resolvedAddress: String?
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Info
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "eye.fill").foregroundColor(.blue)
                        Text(L("Watch-only addresses let you monitor balances and transactions without the ability to sign or send."))
                            .font(.caption).foregroundColor(.blue)
                    }
                    .padding().background(Color.blue.opacity(0.1)).cornerRadius(8)
                    
                    // Address input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Address or ENS")).font(.headline)
                        TextField(L("0x... or name.eth"), text: $address)
                            .padding().background(Color(.systemGray6)).cornerRadius(8)
                            .autocapitalization(.none)
                            .onChange(of: address) { newValue in
                                if newValue.hasSuffix(".eth") { resolveENS(newValue) }
                                else { resolvedAddress = nil }
                            }
                    }
                    
                    // ENS resolved
                    if isResolving {
                        HStack { ProgressView(); Text(L("Resolving ENS...")).font(.caption).foregroundColor(.secondary) }
                    }
                    
                    if let resolved = resolvedAddress {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(resolved).font(.system(.caption, design: .monospaced)).lineLimit(1)
                        }
                        .padding().background(Color.green.opacity(0.1)).cornerRadius(8)
                    }
                    
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                    
                    Button(action: importWatchAddress) {
                        HStack {
                            if isImporting { ProgressView().tint(.white) }
                            Image(systemName: "eye.fill")
                            Text(isImporting ? "Adding..." : "Add Watch Address")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(!effectiveAddress.isEmpty ? Color.blue : Color.gray)
                        .foregroundColor(.white).cornerRadius(12)
                    }
                    .disabled(effectiveAddress.isEmpty || isImporting)
                }
                .padding()
            }
            .navigationTitle(L("Watch Address"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } } }
            .alert(L("Address Added"), isPresented: $showSuccess) {
                Button(L("OK")) { dismiss() }
            } message: { Text(L("Watch address has been added. You can monitor it but cannot sign transactions.")) }
        }
    }
    
    private var effectiveAddress: String {
        resolvedAddress ?? (EthereumUtil.isValidAddress(address) ? address : "")
    }
    
    private func resolveENS(_ name: String) {
        isResolving = true
        Task {
            // In production, resolve ENS via mainnet RPC
            // For now, just validate format
            try? await Task.sleep(nanoseconds: 500_000_000)
            isResolving = false
        }
    }
    
    private func importWatchAddress() {
        let addr = effectiveAddress
        guard !addr.isEmpty else { return }
        isImporting = true; errorMessage = nil
        Task {
            do {
                let keyring = WatchAddressKeyring()
                _ = try keyring.addWatchAddress(addr)
                await KeyringManager.shared.addKeyring(keyring)
                showSuccess = true
            } catch { errorMessage = error.localizedDescription }
            isImporting = false
        }
    }
}

/// Gnosis Safe Import View
/// Corresponds to: src/ui/views/ImportGnosisAddress/
struct GnosisSafeImportView: View {
    @State private var safeAddress = ""
    @State private var selectedChain: Chain?
    @StateObject private var chainManager = ChainManager.shared
    @State private var isLoading = false
    @State private var safeInfo: GnosisKeyring.GnosisSafeInfo?
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Chain selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Network")).font(.headline)
                        Menu {
                            ForEach(chainManager.mainnetChains) { chain in
                                Button(chain.name) { selectedChain = chain }
                            }
                        } label: {
                            HStack {
                                Text(selectedChain?.name ?? "Select Network").foregroundColor(selectedChain == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down").foregroundColor(.secondary)
                            }
                            .padding().background(Color(.systemGray6)).cornerRadius(8)
                        }
                    }
                    
                    // Address input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Safe Address")).font(.headline)
                        TextField(L("0x..."), text: $safeAddress)
                            .padding().background(Color(.systemGray6)).cornerRadius(8)
                            .autocapitalization(.none)
                    }
                    
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                    
                    // Safe info display
                    if let info = safeInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Safe Details")).font(.headline)
                            HStack { Text(L("Threshold")).foregroundColor(.secondary); Spacer(); Text("\(info.threshold) of \(info.owners.count)") }
                            Text(L("Owners")).foregroundColor(.secondary)
                            ForEach(info.owners, id: \.self) { owner in
                                Text(owner).font(.system(.caption, design: .monospaced)).lineLimit(1)
                            }
                        }
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                    }
                    
                    // Actions
                    if safeInfo == nil {
                        Button(action: loadSafeInfo) {
                            HStack {
                                if isLoading { ProgressView().tint(.white) }
                                Text(isLoading ? "Loading..." : "Load Safe")
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(!safeAddress.isEmpty && selectedChain != nil ? Color.blue : Color.gray)
                            .foregroundColor(.white).cornerRadius(12)
                        }
                        .disabled(safeAddress.isEmpty || selectedChain == nil || isLoading)
                    } else {
                        Button(action: importSafe) {
                            Text(L("Import Safe")).fontWeight(.semibold)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(L("Import Gnosis Safe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } } }
            .alert(L("Safe Imported"), isPresented: $showSuccess) {
                Button(L("OK")) { dismiss() }
            }
        }
    }
    
    private func loadSafeInfo() {
        isLoading = true; errorMessage = nil
        Task {
            // In production: call Safe Transaction Service API
            // For now: create mock safe info
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            safeInfo = GnosisKeyring.GnosisSafeInfo(
                address: safeAddress, chainId: selectedChain?.id ?? 1,
                threshold: 2, owners: [safeAddress], version: "1.3.0",
                nonce: 0, networkPrefix: selectedChain?.serverId ?? "eth"
            )
            isLoading = false
        }
    }
    
    private func importSafe() {
        guard let info = safeInfo else { return }
        do {
            let keyring = GnosisKeyring()
            try keyring.addSafe(
                address: info.address, chainId: info.chainId,
                owners: info.owners, threshold: info.threshold
            )
            Task {
                await KeyringManager.shared.addKeyring(keyring)
                showSuccess = true
            }
        } catch { errorMessage = error.localizedDescription }
    }
}

/// JSON Keystore Import View
struct JsonKeystoreImportView: View {
    @State private var keystoreJSON = ""
    @State private var keystorePassword = ""
    @State private var walletPassword = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("JSON Keystore")).font(.headline)
                        TextEditor(text: $keystoreJSON)
                            .frame(minHeight: 150)
                            .padding(4).background(Color(.systemGray6)).cornerRadius(8)
                            .autocapitalization(.none)
                        Text(L("Paste the contents of your JSON keystore file")).font(.caption).foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Keystore Password")).font(.headline)
                        SecureField(L("Password used to encrypt the keystore"), text: $keystorePassword)
                            .padding().background(Color(.systemGray6)).cornerRadius(8)
                    }
                    
                    if !KeyringManager.shared.isInitialized {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("New Wallet Password")).font(.headline)
                            SecureField(L("Create a new wallet password"), text: $walletPassword)
                                .padding().background(Color(.systemGray6)).cornerRadius(8)
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                    
                    Button(action: importKeystore) {
                        HStack {
                            if isImporting { ProgressView().tint(.white) }
                            Text(isImporting ? "Decrypting..." : "Import")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(canImport ? Color.blue : Color.gray)
                        .foregroundColor(.white).cornerRadius(12)
                    }
                    .disabled(!canImport || isImporting)
                }
                .padding()
            }
            .navigationTitle(L("Import JSON Keystore"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } } }
            .alert(L("Import Successful"), isPresented: $showSuccess) {
                Button(L("OK")) { dismiss() }
            }
        }
    }
    
    private var canImport: Bool {
        !keystoreJSON.isEmpty && !keystorePassword.isEmpty &&
        (KeyringManager.shared.isInitialized || walletPassword.count >= 8)
    }
    
    private func importKeystore() {
        isImporting = true; errorMessage = nil
        Task {
            do {
                try await KeyringManager.shared.importFromKeystore(
                    json: keystoreJSON, password: keystorePassword,
                    walletPassword: KeyringManager.shared.isInitialized ? nil : walletPassword
                )
                showSuccess = true
            } catch { errorMessage = error.localizedDescription }
            isImporting = false
        }
    }
}
