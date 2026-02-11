import SwiftUI

/// Select Address View - Address selection after HD wallet derivation
/// Corresponds to: src/ui/views/SelectAddress/
/// Shows derived addresses from HD path so user can pick which to import
struct SelectAddressView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var derivedAddresses: [DerivedAddress] = []
    @State private var selectedAddresses: Set<String> = []
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var currentPage = 0
    @State private var hdPath = "m/44'/60'/0'/0"
    @State private var showPathEditor = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    let mnemonic: String
    let password: String?
    var onComplete: (() -> Void)?
    
    struct DerivedAddress: Identifiable {
        let id: String // address
        let index: Int
        let address: String
        var balance: String?
        var isUsed: Bool
        
        var shortAddress: String {
            guard address.count > 12 else { return address }
            return "\(address.prefix(8))...\(address.suffix(6))"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // HD Path selector
                hdPathSection
                
                // Address list
                if isLoading {
                    Spacer()
                    ProgressView("Deriving addresses...")
                    Spacer()
                } else {
                    addressList
                }
                
                // Bottom bar
                bottomBar
            }
            .navigationTitle("Select Addresses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { deriveAddresses() }
            .sheet(isPresented: $showPathEditor) {
                HDPathEditorSheet(currentPath: $hdPath) {
                    deriveAddresses()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var hdPathSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("HD Path").font(.caption).foregroundColor(.secondary)
                Text(hdPath).font(.system(.subheadline, design: .monospaced))
            }
            Spacer()
            Button(action: { showPathEditor = true }) {
                Label("Edit", systemImage: "pencil")
                    .font(.caption).foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var addressList: some View {
        List {
            ForEach(derivedAddresses) { addr in
                HStack(spacing: 12) {
                    // Selection checkbox
                    Image(systemName: selectedAddresses.contains(addr.address) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedAddresses.contains(addr.address) ? .blue : .gray)
                        .font(.title3)
                    
                    // Index
                    Text("#\(addr.index)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                    
                    // Address
                    VStack(alignment: .leading, spacing: 2) {
                        Text(addr.shortAddress)
                            .font(.system(.subheadline, design: .monospaced))
                        if let balance = addr.balance {
                            Text(balance)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Used indicator
                    if addr.isUsed {
                        Text("Used")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedAddresses.contains(addr.address) {
                        selectedAddresses.remove(addr.address)
                    } else {
                        selectedAddresses.insert(addr.address)
                    }
                }
            }
            
            // Load more
            Button(action: loadMore) {
                HStack {
                    Spacer()
                    Text("Load More Addresses")
                        .font(.subheadline).foregroundColor(.blue)
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let error = errorMessage {
                Text(error).font(.caption).foregroundColor(.red)
            }
            
            HStack {
                Text("\(selectedAddresses.count) selected")
                    .font(.subheadline).foregroundColor(.secondary)
                Spacer()
                
                Button(action: importSelected) {
                    HStack {
                        if isImporting { ProgressView().tint(.white) }
                        Text(isImporting ? "Importing..." : "Import Selected")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(selectedAddresses.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white).cornerRadius(12)
                }
                .disabled(selectedAddresses.isEmpty || isImporting)
            }
        }
        .padding()
        .background(Color(.systemBackground).shadow(color: .black.opacity(0.05), radius: 4, y: -2))
    }
    
    // MARK: - Actions
    
    private func deriveAddresses() {
        isLoading = true
        currentPage = 0
        derivedAddresses = []
        
        Task {
            do {
                let addresses = try await keyringManager.deriveAddresses(
                    mnemonic: mnemonic,
                    hdPath: hdPath,
                    startIndex: 0,
                    count: 5
                )
                derivedAddresses = addresses.enumerated().map { (index, addr) in
                    DerivedAddress(id: addr, index: index, address: addr, balance: nil, isUsed: false)
                }
                // Auto-select first address
                if let first = derivedAddresses.first {
                    selectedAddresses.insert(first.address)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func loadMore() {
        currentPage += 1
        Task {
            do {
                let startIndex = (currentPage + 1) * 5
                let addresses = try await keyringManager.deriveAddresses(
                    mnemonic: mnemonic,
                    hdPath: hdPath,
                    startIndex: startIndex,
                    count: 5
                )
                let newAddresses = addresses.enumerated().map { (index, addr) in
                    DerivedAddress(id: addr, index: startIndex + index, address: addr, balance: nil, isUsed: false)
                }
                derivedAddresses.append(contentsOf: newAddresses)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func importSelected() {
        isImporting = true
        errorMessage = nil
        Task {
            do {
                try await keyringManager.importFromMnemonic(
                    mnemonic: mnemonic,
                    password: password,
                    accountCount: selectedAddresses.count
                )
                onComplete?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isImporting = false
        }
    }
}

/// HD Path Editor Sheet
struct HDPathEditorSheet: View {
    @Binding var currentPath: String
    var onPathChanged: () -> Void
    @State private var customPath = ""
    @Environment(\.dismiss) var dismiss
    
    let commonPaths = [
        ("Ethereum (Default)", "m/44'/60'/0'/0"),
        ("Ethereum Classic", "m/44'/61'/0'/0"),
        ("Ledger Live", "m/44'/60'/0'"),
        ("BIP44 Standard", "m/44'/60'/0'/0"),
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Common Paths") {
                    ForEach(commonPaths, id: \.1) { (name, path) in
                        Button(action: {
                            currentPath = path
                            onPathChanged()
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name).foregroundColor(.primary)
                                    Text(path).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
                                }
                                Spacer()
                                if currentPath == path {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("Custom Path") {
                    TextField("m/44'/60'/0'/0", text: $customPath)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                    
                    Button("Apply Custom Path") {
                        if !customPath.isEmpty {
                            currentPath = customPath
                            onPathChanged()
                            dismiss()
                        }
                    }
                    .disabled(customPath.isEmpty)
                }
            }
            .navigationTitle("HD Path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
