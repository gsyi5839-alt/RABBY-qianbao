import SwiftUI

/// Import wallet flow
struct ImportWalletView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var keyringManager = KeyringManager.shared
    
    @State private var importType: ImportType = .mnemonic
    @State private var mnemonicInput = ""
    @State private var privateKeyInput = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isImporting = false
    
    enum ImportType {
        case mnemonic
        case privateKey
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L("Import Type"))) {
                    Picker(L("Type"), selection: $importType) {
                        Text(L("Secret Phrase")).tag(ImportType.mnemonic)
                        Text(L("Private Key")).tag(ImportType.privateKey)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text(importType == .mnemonic ? "Secret Phrase" : "Private Key")) {
                    if importType == .mnemonic {
                        mnemonicSection
                    } else {
                        privateKeySection
                    }
                }
                
                Section(header: Text(L("Set Password"))) {
                    SecureField(L("Password"), text: $password)
                        .autocapitalization(.none)
                    
                    SecureField(L("Confirm Password"), text: $confirmPassword)
                        .autocapitalization(.none)
                }
                
                Section {
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: importWallet) {
                        if isImporting {
                            HStack {
                                ProgressView()
                                Text(L("Importing..."))
                            }
                        } else {
                            Text(L("Import Wallet"))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!canImport || isImporting)
                }
            }
            .navigationTitle(L("Import Wallet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Mnemonic Section
    
    private var mnemonicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $mnemonicInput)
                .frame(minHeight: 120)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            Text(L("Enter your 12 or 24 word secret phrase"))
                .font(.caption)
                .foregroundColor(.gray)
            
            if HDKeyring.validateMnemonic(mnemonicInput.trimmingCharacters(in: .whitespacesAndNewlines)) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L("Valid mnemonic"))
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Private Key Section
    
    private var privateKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $privateKeyInput)
                .frame(minHeight: 100)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            Text(L("Enter your private key (with or without 0x prefix)"))
                .font(.caption)
                .foregroundColor(.gray)
            
            if isValidPrivateKey(privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L("Valid private key"))
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var canImport: Bool {
        let passwordValid = password.count >= 8 && password == confirmPassword
        
        if importType == .mnemonic {
            let mnemonic = mnemonicInput.trimmingCharacters(in: .whitespacesAndNewlines)
            return HDKeyring.validateMnemonic(mnemonic) && passwordValid
        } else {
            let privateKey = privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            return isValidPrivateKey(privateKey) && passwordValid
        }
    }
    
    private func isValidPrivateKey(_ key: String) -> Bool {
        var cleanKey = key
        if cleanKey.hasPrefix("0x") {
            cleanKey = String(cleanKey.dropFirst(2))
        }
        
        guard cleanKey.count == 64 else { return false }
        
        return cleanKey.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil
    }
    
    // MARK: - Import Action
    
    private func importWallet() {
        errorMessage = ""
        isImporting = true
        
        Task {
            do {
                // Create vault with password
                await keyringManager.createNewVault(password: password)
                
                if importType == .mnemonic {
                    try await importFromMnemonic()
                } else {
                    try await importFromPrivateKey()
                }
                
                // Save vault
                try await keyringManager.persistAllKeyrings()
                
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Import failed: \(error.localizedDescription)"
                    isImporting = false
                }
            }
        }
    }
    
    private func importFromMnemonic() async throws {
        let mnemonic = mnemonicInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let keyring = HDKeyring(mnemonic: mnemonic)
        _ = try await keyring.addAccounts(count: 1)
        
        await keyringManager.addKeyring(keyring)
    }
    
    private func importFromPrivateKey() async throws {
        var cleanKey = privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanKey.hasPrefix("0x") {
            cleanKey = String(cleanKey.dropFirst(2))
        }
        
        guard let privateKeyData = Data(hexString: cleanKey) else {
            throw ImportError.invalidPrivateKey
        }
        
        let keyring = SimpleKeyring()
        _ = try keyring.addAccounts(privateKeys: [privateKeyData])
        
        await keyringManager.addKeyring(keyring)
    }
}

// MARK: - Errors

enum ImportError: Error, LocalizedError {
    case invalidPrivateKey
    case importFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPrivateKey:
            return "Invalid private key format"
        case .importFailed:
            return "Failed to import wallet"
        }
    }
}

// MARK: - Preview

struct ImportWalletView_Previews: PreviewProvider {
    static var previews: some View {
        ImportWalletView()
    }
}
