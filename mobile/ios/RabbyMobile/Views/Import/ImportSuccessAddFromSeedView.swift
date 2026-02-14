import SwiftUI

/// Import Success View - Shown after wallet import completes
/// Corresponds to: src/ui/views/ImportSuccess/
struct ImportSuccessView: View {
    let address: String
    let importType: String
    let onDone: () -> Void
    
    @State private var aliasName = ""
    @State private var showCopied = false
    @StateObject private var prefManager = PreferenceManager.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 90, height: 90)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 8) {
                Text(L("Import Successful!"))
                    .font(.title2).fontWeight(.bold)
                
                Text("Your \(importType) wallet has been imported")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            
            // Address card
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(address.dropFirst(2).prefix(2)))
                                .font(.caption).fontWeight(.bold).foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(aliasName.isEmpty ? "Account" : aliasName)
                            .font(.subheadline).fontWeight(.medium)
                        Text(shortAddress)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: copyAddress) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .foregroundColor(showCopied ? .green : .blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Set alias
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Set a name (optional)"))
                    .font(.caption).foregroundColor(.secondary)
                
                TextField(L("Enter a name for this address"), text: $aliasName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onChange(of: aliasName) { newValue in
                        if !newValue.isEmpty {
                            prefManager.setAlias(address: address, alias: newValue)
                        }
                    }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Done button
            Button(action: onDone) {
                Text(L("Done"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
    
    private var shortAddress: String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(8))...\(address.suffix(6))"
    }
    
    private func copyAddress() {
        UIPasteboard.general.string = address
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }
}

/// Add From Current Seed Phrase View
/// Corresponds to: src/ui/views/AddFromCurrentSeedPhrase/
/// Allows adding more addresses from an already imported HD wallet
struct AddFromSeedPhraseView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var derivedAddresses: [DerivedAddressItem] = []
    @State private var selectedAddresses: Set<String> = []
    @State private var isLoading = true
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    struct DerivedAddressItem: Identifiable {
        let id: String
        let index: Int
        let address: String
        let isExisting: Bool
        
        var shortAddress: String {
            guard address.count > 12 else { return address }
            return "\(address.prefix(8))...\(address.suffix(6))"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Info banner
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundColor(.blue)
                    Text(L("Select additional addresses to add from your existing seed phrase. Existing addresses are marked."))
                        .font(.caption).foregroundColor(.blue)
                }
                .padding().background(Color.blue.opacity(0.1))
                
                if isLoading {
                    Spacer()
                    ProgressView(L("Deriving addresses..."))
                    Spacer()
                } else {
                    // Address list
                    List {
                        ForEach(derivedAddresses) { item in
                            HStack(spacing: 12) {
                                if item.isExisting {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: selectedAddresses.contains(item.address) ?
                                          "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedAddresses.contains(item.address) ? .blue : .gray)
                                }
                                
                                Text("#\(item.index)")
                                    .font(.caption).foregroundColor(.secondary)
                                    .frame(width: 30)
                                
                                Text(item.shortAddress)
                                    .font(.system(.subheadline, design: .monospaced))
                                
                                Spacer()
                                
                                if item.isExisting {
                                    Text(L("Added"))
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.green.opacity(0.1)).cornerRadius(4)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !item.isExisting else { return }
                                if selectedAddresses.contains(item.address) {
                                    selectedAddresses.remove(item.address)
                                } else {
                                    selectedAddresses.insert(item.address)
                                }
                            }
                            .opacity(item.isExisting ? 0.6 : 1.0)
                        }
                    }
                    .listStyle(.plain)
                }
                
                // Bottom bar
                VStack(spacing: 8) {
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                    
                    Button(action: addSelected) {
                        HStack {
                            if isAdding { ProgressView().tint(.white) }
                            Text(isAdding ? "Adding..." : "Add \(selectedAddresses.count) Address(es)")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(selectedAddresses.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white).cornerRadius(12)
                    }
                    .disabled(selectedAddresses.isEmpty || isAdding)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle(L("Add Address"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
            .onAppear { loadAddresses() }
            .alert(L("Addresses Added"), isPresented: $showSuccess) {
                Button(L("Done")) { dismiss() }
            } message: {
                Text("\(selectedAddresses.count) new address(es) have been added to your wallet.")
            }
        }
    }
    
    private func loadAddresses() {
        isLoading = true
        Task {
            do {
                let existing = await keyringManager.getAllAddresses()
                let addresses = try await keyringManager.deriveAddresses(
                    mnemonic: "", // Uses stored mnemonic
                    hdPath: "m/44'/60'/0'/0",
                    startIndex: 0,
                    count: 10
                )
                derivedAddresses = addresses.enumerated().map { (idx, addr) in
                    DerivedAddressItem(
                        id: addr, index: idx, address: addr,
                        isExisting: existing.contains(where: { $0.lowercased() == addr.lowercased() })
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func addSelected() {
        isAdding = true
        Task {
            do {
                for address in selectedAddresses {
                    try await keyringManager.addAccountFromExistingMnemonic(address: address)
                }
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isAdding = false
        }
    }
}
