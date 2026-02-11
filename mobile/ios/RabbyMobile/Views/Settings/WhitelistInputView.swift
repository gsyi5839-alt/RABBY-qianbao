import SwiftUI

/// Whitelist Input View - Manage whitelisted addresses for send transactions
/// Corresponds to: src/ui/views/WhitelistInput/
/// When whitelist is enabled, user can only send to these addresses
struct WhitelistInputView: View {
    @StateObject private var whitelistManager = WhitelistManager.shared
    @StateObject private var contactBook = ContactBookManager.shared
    @StateObject private var prefManager = PreferenceManager.shared
    @State private var newAddress = ""
    @State private var newAlias = ""
    @State private var showAddSheet = false
    @State private var editingAddress: String?
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var addressToDelete: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status banner
                whitelistBanner
                
                // Address list
                if whitelistManager.whitelistedAddresses.isEmpty {
                    emptyState
                } else {
                    addressList
                }
            }
            .navigationTitle("Whitelist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addAddressSheet
            }
            .alert("Remove Address", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let addr = addressToDelete {
                        whitelistManager.removeFromWhitelist(addr)
                    }
                }
            } message: {
                Text("This address will be removed from the whitelist. You won't be able to send to it when whitelist is enabled.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var whitelistBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: prefManager.isWhitelistEnabled ? "shield.checkered" : "shield.slash")
                .font(.title3)
                .foregroundColor(prefManager.isWhitelistEnabled ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(prefManager.isWhitelistEnabled ? "Whitelist Active" : "Whitelist Disabled")
                    .font(.subheadline).fontWeight(.medium)
                Text(prefManager.isWhitelistEnabled ?
                     "Only addresses below can receive your transfers" :
                     "Enable whitelist in Settings > Security")
                    .font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { prefManager.isWhitelistEnabled },
                set: { prefManager.setWhitelistEnabled($0) }
            ))
            .labelsHidden()
        }
        .padding()
        .background(prefManager.isWhitelistEnabled ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48)).foregroundColor(.gray)
            Text("No whitelisted addresses")
                .font(.headline).foregroundColor(.secondary)
            Text("Add addresses that you frequently send to for extra security")
                .font(.caption).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            
            Button(action: { showAddSheet = true }) {
                Label("Add Address", systemImage: "plus")
                    .font(.headline).padding()
                    .background(Color.blue).foregroundColor(.white).cornerRadius(12)
            }
            Spacer()
        }
    }
    
    private var addressList: some View {
        List {
            ForEach(whitelistManager.whitelistedAddresses, id: \.self) { address in
                HStack(spacing: 12) {
                    // Avatar
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(address.dropFirst(2).prefix(2)))
                                .font(.caption2).fontWeight(.bold).foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Alias from contacts
                        if let contact = contactBook.getContact(by: address) {
                            Text(contact.name).font(.subheadline).fontWeight(.medium)
                        }
                        Text(formatAddress(address))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Copy button
                    Button(action: { UIPasteboard.general.string = address }) {
                        Image(systemName: "doc.on.doc").font(.caption).foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        addressToDelete = address
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var addAddressSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Address").font(.headline)
                    TextField("0x...", text: $newAddress)
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                        .autocapitalization(.none)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alias (Optional)").font(.headline)
                    TextField("Enter a name for this address", text: $newAlias)
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                }
                
                if let error = errorMessage {
                    Text(error).font(.caption).foregroundColor(.red)
                }
                
                // Quick add from contacts
                if !contactBook.contacts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("From Contacts").font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(contactBook.contacts.filter {
                                    !whitelistManager.whitelistedAddresses.contains($0.address)
                                }, id: \.address) { contact in
                                    Button(action: {
                                        newAddress = contact.address
                                        newAlias = contact.name
                                    }) {
                                        VStack(spacing: 4) {
                                            Circle().fill(Color.blue.opacity(0.2)).frame(width: 32, height: 32)
                                                .overlay(Text(String(contact.name.prefix(1))).font(.caption).foregroundColor(.blue))
                                            Text(contact.name).font(.caption2).foregroundColor(.primary)
                                        }
                                        .padding(8).background(Color(.systemGray6)).cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: addAddress) {
                    Text("Add to Whitelist")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding()
                        .background(canAdd ? Color.blue : Color.gray)
                        .foregroundColor(.white).cornerRadius(12)
                }
                .disabled(!canAdd)
            }
            .padding()
            .navigationTitle("Add Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddSheet = false }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var canAdd: Bool {
        !newAddress.isEmpty && EthereumUtil.isValidAddress(newAddress) &&
        !whitelistManager.whitelistedAddresses.contains(newAddress.lowercased())
    }
    
    private func addAddress() {
        guard canAdd else {
            errorMessage = "Invalid address or already whitelisted"
            return
        }
        do {
        try whitelistManager.addToWhitelist(newAddress)
        if !newAlias.isEmpty {
            try contactBook.addContact(name: newAlias, address: newAddress)
        }
        newAddress = ""
        newAlias = ""
        errorMessage = nil
        showAddSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func formatAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(8))...\(address.suffix(6))"
    }
}
