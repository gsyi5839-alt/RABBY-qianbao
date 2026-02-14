import SwiftUI

/// View for adding custom tokens by contract address
/// Corresponds to: src/ui/views/Dashboard/components/AddTokenEntry/
struct AddCustomTokenView: View {
    @StateObject private var tokenManager = TokenManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var contractAddress = ""
    @State private var selectedChain: Chain?
    @State private var isSearching = false
    @State private var foundToken: TokenItem?
    @State private var errorMessage: String?
    @State private var addedSuccess = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Chain selector
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Network"))
                        .font(.headline)
                    
                    Menu {
                        ForEach(chainManager.mainnetChains) { chain in
                            Button(chain.name) {
                                selectedChain = chain
                                foundToken = nil
                                errorMessage = nil
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedChain?.name ?? "Select Network")
                                .foregroundColor(selectedChain == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                
                // Contract address input
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Contract Address"))
                        .font(.headline)
                    
                    HStack {
                        TextField(L("0x..."), text: $contractAddress)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !contractAddress.isEmpty {
                            Button(action: { contractAddress = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Paste button
                        Button(action: pasteAddress) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                // Search button
                Button(action: searchToken) {
                    HStack {
                        if isSearching {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(L("Search Token"))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSearch ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSearch)
                
                // Error message
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Token preview
                if let token = foundToken {
                    tokenPreview(token)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(L("Add Custom Token"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
            .overlay {
                if addedSuccess {
                    successOverlay
                }
            }
        }
    }
    
    // MARK: - Token Preview
    
    private func tokenPreview(_ token: TokenItem) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Token icon
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(token.symbol.prefix(1)))
                            .font(.title3).fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(token.symbol)
                        .font(.headline)
                    Text(token.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Decimals: \(token.decimals)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let chain = selectedChain {
                        Text(chain.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Add button
            Button(action: addToken) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(L("Add Token"))
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text(L("Token Added!"))
                .font(.title2).fontWeight(.bold)
            Text(L("The token has been added to your list"))
                .font(.subheadline).foregroundColor(.secondary)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Actions
    
    private var canSearch: Bool {
        !isSearching && selectedChain != nil && contractAddress.count > 10
    }
    
    private func pasteAddress() {
        if let text = UIPasteboard.general.string {
            contractAddress = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private func searchToken() {
        guard let chain = selectedChain else { return }
        isSearching = true
        errorMessage = nil
        foundToken = nil
        
        Task {
            do {
                let token = try await tokenManager.importToken(address: contractAddress, chain: chain)
                // Remove from custom tokens since we just want to preview first
                tokenManager.removeCustomToken(token)
                foundToken = token
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }
    
    private func addToken() {
        guard let token = foundToken else { return }
        do {
            try tokenManager.addCustomToken(token)
            withAnimation(.spring()) { addedSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
