import SwiftUI

/// Gas Account View - Gas sponsorship/deposit
/// Corresponds to: src/ui/views/GasAccount/
struct GasAccountView: View {
    @StateObject private var gasManager = GasAccountManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var depositAmount = ""
    @State private var isDepositing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Balance card
                VStack(spacing: 8) {
                    Text("Gas Account").font(.headline).foregroundColor(.secondary)
                    Text("$\(String(format: "%.4f", gasManager.balance))")
                        .font(.system(size: 36, weight: .bold))
                    Text("Available for gas sponsorship")
                        .font(.caption).foregroundColor(.secondary)
                    
                    if gasManager.isActivated {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundColor(.green)
                    } else {
                        Label("Inactive", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(16)
                
                // Deposit section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Deposit").font(.headline)
                    
                    HStack {
                        TextField("Amount in USD", text: $depositAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: deposit) {
                            if isDepositing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Deposit")
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                        .disabled(depositAmount.isEmpty || isDepositing)
                    }
                }
                .padding()
                .background(Color(.systemBackground)).cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4)
                
                // How it works
                VStack(alignment: .leading, spacing: 12) {
                    Text("How Gas Account Works").font(.headline)
                    
                    infoRow(icon: "fuelpump.fill", text: "Deposit funds to your gas account")
                    infoRow(icon: "bolt.fill", text: "Gas fees are paid from your gas account balance")
                    infoRow(icon: "checkmark.shield.fill", text: "No need to hold native tokens on every chain")
                    infoRow(icon: "globe", text: "Works across all supported chains")
                }
                .padding()
                .background(Color(.systemGray6)).cornerRadius(12)
                
                // Transaction history
                if !gasManager.transactions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("History").font(.headline)
                        ForEach(gasManager.transactions.prefix(10)) { tx in
                            HStack {
                                Image(systemName: tx.type == "deposit" ? "plus.circle.fill" : "minus.circle.fill")
                                    .foregroundColor(tx.type == "deposit" ? .green : .orange)
                                VStack(alignment: .leading) {
                                    Text(tx.type.capitalized).font(.subheadline)
                                    Text(tx.date, style: .relative).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(tx.type == "deposit" ? "+$\(String(format: "%.4f", tx.amount))" : "-$\(String(format: "%.4f", tx.amount))")
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(tx.type == "deposit" ? .green : .primary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground)).cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4)
                }
            }
            .padding()
        }
        .navigationTitle("Gas Account")
    }
    
    private func deposit() {
        guard let amount = Double(depositAmount) else { return }
        isDepositing = true
        Task {
            await gasManager.deposit(amount: amount)
            isDepositing = false
            depositAmount = ""
        }
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 24)
            Text(text).font(.subheadline)
        }
    }
}

/// WalletConnect Session View - Manage WC connections
/// Corresponds to: src/ui/views/WalletConnect/
struct WalletConnectView: View {
    @StateObject private var wcManager = WalletConnectManager.shared
    @State private var pairingURI = ""
    @State private var showScanner = false
    @State private var isPairing = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection input
                VStack(spacing: 12) {
                    Text("Connect DApp").font(.headline)
                    
                    TextField("Paste WalletConnect URI", text: $pairingURI)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    
                    HStack(spacing: 12) {
                        Button(action: { showScanner = true }) {
                            Label("Scan QR", systemImage: "qrcode.viewfinder")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color(.systemGray6)).cornerRadius(12)
                        }
                        
                        Button(action: pair) {
                            if isPairing {
                                HStack { ProgressView().tint(.white); Text("Connecting...") }
                            } else {
                                Text("Connect")
                            }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(pairingURI.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white).cornerRadius(12)
                        .disabled(pairingURI.isEmpty || isPairing)
                    }
                    
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                }
                .padding().background(Color(.systemBackground)).cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4)
                
                // Active sessions
                if !wcManager.sessions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Sessions").font(.headline)
                        
                        ForEach(wcManager.sessions) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.peerName).fontWeight(.medium)
                                    Text(session.peerUrl).font(.caption).foregroundColor(.secondary)
                                    Text("Connected \(session.createdAt, style: .relative) ago")
                                        .font(.caption2).foregroundColor(.gray)
                                }
                                Spacer()
                                Circle().fill(Color.green).frame(width: 8, height: 8)
                            }
                            .padding().background(Color(.systemGray6)).cornerRadius(8)
                            .swipeActions {
                Button("Disconnect") { wcManager.disconnectSession(session.id) }
                                    .tint(.red)
                            }
                        }
                    }
                }
                
                // How it works
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Connect").font(.headline)
                    stepRow(number: 1, text: "Open a DApp in your browser")
                    stepRow(number: 2, text: "Click 'Connect Wallet' and select WalletConnect")
                    stepRow(number: 3, text: "Scan the QR code or paste the URI")
                    stepRow(number: 4, text: "Approve the connection in Rabby")
                }
                .padding().background(Color(.systemGray6)).cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("WalletConnect")
    }
    
    private func pair() {
        isPairing = true; errorMessage = nil
        Task {
            do {
                try await wcManager.pair(uri: pairingURI)
                pairingURI = ""
            } catch { errorMessage = error.localizedDescription }
            isPairing = false
        }
    }
    
    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Color.blue).frame(width: 24, height: 24)
                .overlay(Text("\(number)").font(.caption2).fontWeight(.bold).foregroundColor(.white))
            Text(text).font(.subheadline)
        }
    }
}

/// Chain List View - View and manage supported chains
/// Corresponds to: src/ui/views/ChainList/
struct ChainListView: View {
    @StateObject private var chainManager = ChainManager.shared
    @State private var searchText = ""
    @State private var showTestnets = false
    
    var filteredChains: [Chain] {
        let chains = showTestnets ? chainManager.mainnetChains + chainManager.testnetChains : chainManager.mainnetChains
        if searchText.isEmpty { return chains }
        return chains.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.symbol.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List {
            Toggle("Show Testnets", isOn: $showTestnets)
            
            ForEach(filteredChains) { chain in
                HStack {
                    Circle().fill(Color.blue.opacity(0.2)).frame(width: 36, height: 36)
                        .overlay(Text(String(chain.symbol.prefix(2))).font(.caption).fontWeight(.bold).foregroundColor(.blue))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chain.name).fontWeight(.medium)
                        Text("Chain ID: \(chain.id)").font(.caption).foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(chain.symbol).font(.caption).foregroundColor(.blue)
                    
                    if chain.id == chainManager.selectedChain?.id {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { chainManager.selectChain(chain) }
            }
        }
        .searchable(text: $searchText, prompt: "Search chains")
        .navigationTitle("Chains")
    }
}
