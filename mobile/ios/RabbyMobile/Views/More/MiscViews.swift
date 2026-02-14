import SwiftUI
import CoreImage.CIFilterBuiltins

/// Forgot Password View
/// Corresponds to: src/ui/views/ForgotPassword/
struct ForgotPasswordView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var seedPhrase = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text(L("You can only reset your password if you have your seed phrase. This will restore your wallet with the new password."))
                            .font(.subheadline).foregroundColor(.orange)
                    }
                    .padding().background(Color.orange.opacity(0.1)).cornerRadius(8)
                    
                    // Seed phrase
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Enter Seed Phrase")).font(.headline)
                        TextEditor(text: $seedPhrase)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .autocapitalization(.none)
                        Text(L("Enter your 12 or 24 word seed phrase, separated by spaces"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    
                    // New password
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("New Password")).font(.headline)
                        SecureField(L("Enter new password"), text: $newPassword)
                            .textFieldStyle(.roundedBorder)
                        SecureField(L("Confirm new password"), text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                        
                        if newPassword.count > 0 && newPassword.count < 8 {
                            Text(L("Password must be at least 8 characters")).font(.caption).foregroundColor(.red)
                        }
                        if !confirmPassword.isEmpty && newPassword != confirmPassword {
                            Text(L("Passwords do not match")).font(.caption).foregroundColor(.red)
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                    
                    // Restore button
                    Button(action: restoreWallet) {
                        if isRestoring {
                            HStack { ProgressView().tint(.white); Text(L("Restoring...")) }
                        } else {
                            Text(L("Reset Password & Restore"))
                        }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(isValid ? Color.blue : Color.gray)
                    .foregroundColor(.white).cornerRadius(12)
                    .disabled(!isValid || isRestoring)
                }
                .padding()
            }
            .navigationTitle(L("Forgot Password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
            }
            .alert(L("Wallet Restored"), isPresented: $showSuccess) {
                Button(L("OK")) { dismiss() }
            } message: {
                Text(L("Your wallet has been restored with the new password."))
            }
        }
    }
    
    private var isValid: Bool {
        !seedPhrase.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
    }
    
    private func restoreWallet() {
        isRestoring = true; errorMessage = nil
        Task {
            do {
                try await keyringManager.restoreFromMnemonic(
                    mnemonic: seedPhrase.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: newPassword
                )
                showSuccess = true
            } catch { errorMessage = error.localizedDescription }
            isRestoring = false
        }
    }
}

/// Signed Text History View
/// Corresponds to: src/ui/views/SignedTextHistory/
struct SignedTextHistoryView: View {
    @StateObject private var signHistory = SignHistoryManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    
    var body: some View {
        Group {
            if records.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "signature").font(.system(size: 48)).foregroundColor(.gray)
                    Text(L("No signed messages")).foregroundColor(.secondary)
                    Text(L("Messages you sign from DApps will appear here")).font(.caption).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(records) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(record.type.rawValue).font(.caption).fontWeight(.semibold)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(typeColor(record.type).opacity(0.2))
                                .foregroundColor(typeColor(record.type))
                                .cornerRadius(4)
                            Spacer()
                            Text(record.timestamp, style: .relative).font(.caption2).foregroundColor(.secondary)
                        }
                        
                        if let dappInfo = record.dappInfo {
                            Text(dappInfo.origin).font(.caption).foregroundColor(.blue)
                        }
                        
                        Text(record.message.prefix(200) + (record.message.count > 200 ? "..." : ""))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(L("Signed Messages"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !records.isEmpty {
                    Button(L("Clear All")) { clearHistory() }.foregroundColor(.red)
                }
            }
        }
    }
    
    private var records: [SignHistoryManager.SignHistoryItem] {
        guard let address = keyringManager.currentAccount?.address else { return [] }
        return signHistory.getHistory(for: address)
    }
    
    private func typeColor(_ type: SignHistoryManager.SignType) -> Color {
        switch type {
        case .personalSign: return .blue
        case .signTypedData: return .purple
        case .signTypedDataV3: return .orange
        case .signTypedDataV4: return .green
        case .transaction: return .red
        }
    }
    
    private func clearHistory() {
        guard let address = keyringManager.currentAccount?.address else { return }
        signHistory.clearHistory(for: address)
    }
}

