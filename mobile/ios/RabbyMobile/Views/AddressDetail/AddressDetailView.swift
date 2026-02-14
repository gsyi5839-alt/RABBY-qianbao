import SwiftUI

/// Address Detail View - Shows detailed info about an address
/// Corresponds to: src/ui/views/AddressDetail/
struct AddressDetailView: View {
    let address: String
    @StateObject private var prefManager = PreferenceManager.shared
    @StateObject private var tokenManager = TokenManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var aliasName = ""
    @State private var showBackup = false
    @State private var showDelete = false
    @State private var showEditAlias = false
    @State private var totalBalance: Double = 0
    @State private var tokenCount: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Address card
                addressCard
                
                // Quick actions
                quickActions
                
                // Balance info
                balanceSection
                
                // Chain breakdown
                chainBreakdown
                
                // Management
                managementSection
            }
            .padding()
        }
        .navigationTitle(L("Address Detail"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditAlias) {
            EditAliasSheet(address: address, currentAlias: aliasName) { newAlias in
                aliasName = newAlias
            }
        }
        .sheet(isPresented: $showBackup) {
            AddressBackupView()
        }
        .alert(L("Delete Address"), isPresented: $showDelete) {
            Button(L("Delete"), role: .destructive) { deleteAddress() }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("This will remove the address from your wallet. Make sure you have backed up your seed phrase or private key."))
        }
        .onAppear { loadAddressInfo() }
    }
    
    private var addressCard: some View {
        VStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
                .overlay(
                    Text(String(address.dropFirst(2).prefix(2)).uppercased())
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                )
            
            // Alias name
            HStack(spacing: 4) {
                Text(aliasName.isEmpty ? "Unnamed" : aliasName)
                    .font(.title3).fontWeight(.semibold)
                Button(action: { showEditAlias = true }) {
                    Image(systemName: "pencil.circle").foregroundColor(.blue)
                }
            }
            
            // Address
            HStack {
                Text(address)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Button(action: { UIPasteboard.general.string = address }) {
                    Image(systemName: "doc.on.doc").font(.caption).foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Account type badge
            HStack(spacing: 6) {
                Image(systemName: accountTypeIcon).font(.caption)
                Text(accountType).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionButton(icon: "arrow.up.circle.fill", title: "Send", color: .blue) {}
            QuickActionButton(icon: "arrow.down.circle.fill", title: "Receive", color: .green) {}
            QuickActionButton(icon: "doc.on.doc", title: "Copy", color: .orange) {
                UIPasteboard.general.string = address
            }
            QuickActionButton(icon: "safari", title: "Explorer", color: .purple) {
                if let chain = chainManager.selectedChain, let url = URL(string: "\(chain.scanUrl)/address/\(address)") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Balance")).font(.headline)
            
            HStack {
                Text("$\(String(format: "%.2f", totalBalance))")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                Text("\(tokenCount) tokens")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    private var chainBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Assets by Chain")).font(.headline)
            
            ForEach(chainManager.mainnetChains.prefix(5)) { chain in
                HStack {
                    Circle().fill(Color.blue.opacity(0.2)).frame(width: 28, height: 28)
                        .overlay(Text(String(chain.symbol.prefix(1))).font(.caption2).fontWeight(.bold).foregroundColor(.blue))
                    Text(chain.name).font(.subheadline)
                    Spacer()
                    Text(L("$0.00")).font(.subheadline).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    private var managementSection: some View {
        VStack(spacing: 12) {
            Button(action: { showBackup = true }) {
                HStack {
                    Image(systemName: "key.fill").foregroundColor(.orange)
                    Text(L("Backup Seed Phrase / Private Key")).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
                .padding().background(Color(.systemGray6)).cornerRadius(12)
            }
            
            Button(action: { showDelete = true }) {
                HStack {
                    Image(systemName: "trash.fill").foregroundColor(.red)
                    Text(L("Remove Address")).foregroundColor(.red)
                    Spacer()
                }
                .padding().background(Color.red.opacity(0.1)).cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var accountType: String {
        // Determine account type
        return "HD Wallet"
    }
    
    private var accountTypeIcon: String {
        return "key.fill"
    }
    
    private func loadAddressInfo() {
        aliasName = prefManager.getAlias(address: address) ?? ""
    }
    
    private func deleteAddress() {
        prefManager.removeAccount(address)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundColor(color)
                Text(title).font(.caption2).foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct EditAliasSheet: View {
    let address: String
    let currentAlias: String
    var onSave: (String) -> Void
    @State private var aliasText = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField(L("Enter alias name"), text: $aliasText)
            }
            .navigationTitle(L("Edit Alias"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save")) {
                        PreferenceManager.shared.setAlias(address: address, alias: aliasText)
                        onSave(aliasText)
                        dismiss()
                    }
                }
            }
        }
        .onAppear { aliasText = currentAlias }
    }
}
