import SwiftUI

/// WalletConnect Pairing View
/// Allows users to connect to DApps via WalletConnect v2
struct WalletConnectPairView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var wcManager = WalletConnectManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    
    @State private var showScanner = false
    @State private var showManualInput = false
    @State private var manualURI = ""
    @State private var errorMessage: String?
    @State private var isPairing = false
    @State private var pairingSuccess = false
    
    private let L = LocalizationManager.shared.t
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Logo
                    Image(systemName: "link.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                        .padding(.top, 40)
                    
                    // Title and description
                    VStack(spacing: 12) {
                        Text(L("ios.walletConnect.connectToDApp"))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(L("ios.walletConnect.scanDescription"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Scan button
                    Button {
                        checkPermissionAndScan()
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title3)
                            Text(L("ios.walletConnect.scanQRCode"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isPairing)
                    .padding(.horizontal)
                    
                    // Manual input button
                    Button {
                        showManualInput = true
                    } label: {
                        HStack {
                            Image(systemName: "text.cursor")
                                .font(.title3)
                            Text(L("ios.walletConnect.pasteURI"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                    }
                    .disabled(isPairing)
                    .padding(.horizontal)
                    
                    // Loading indicator
                    if isPairing {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(L("ios.walletConnect.connecting"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Success message
                    if pairingSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(L("ios.walletConnect.connectedSuccessfully"))
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("ios.common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            UniversalQRScannerView(purpose: .walletConnect) { code in
                handleScannedURI(code)
            }
        }
        .alert(L("ios.walletConnect.pasteURI"), isPresented: $showManualInput) {
            TextField("wc:...", text: $manualURI)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(L("ios.common.cancel"), role: .cancel) {}
            Button(L("ios.common.connect")) {
                handleScannedURI(manualURI)
            }
        } message: {
            Text(L("ios.walletConnect.pasteURIDescription"))
        }
    }
    
    private func checkPermissionAndScan() {
        Task {
            let hasPermission = await PermissionManager.requestCameraPermission()
            if hasPermission {
                await MainActor.run {
                    showScanner = true
                }
            } else {
                await MainActor.run {
                    errorMessage = L("ios.error.cameraPermissionDenied")
                }
            }
        }
    }
    
    private func handleScannedURI(_ uri: String) {
        guard uri.hasPrefix("wc:") || uri.hasPrefix("wc@") else {
            errorMessage = L("ios.walletConnect.invalidURI")
            return
        }
        
        isPairing = true
        errorMessage = nil
        pairingSuccess = false
        
        Task {
            do {
                // Pair with the URI
                try await wcManager.pair(uri: uri)
                
                await MainActor.run {
                    isPairing = false
                    pairingSuccess = true
                    
                    // Auto-dismiss after 1.5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPairing = false
                    errorMessage = L("ios.walletConnect.pairingFailed") + ": \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Active Sessions View

struct WalletConnectSessionsView: View {
    @StateObject private var wcManager = WalletConnectManager.shared
    @Environment(\.dismiss) var dismiss
    
    private let L = LocalizationManager.shared.t
    
    var body: some View {
        NavigationView {
            List {
                if wcManager.activeSessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text(L("ios.walletConnect.noActiveSessions"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(wcManager.activeSessions, id: \.topic) { session in
                        SessionRow(session: session) {
                            disconnectSession(session)
                        }
                    }
                }
            }
            .navigationTitle(L("ios.walletConnect.activeSessions"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text(L("ios.common.done"))
                    }
                }
            }
        }
    }
    
    private func disconnectSession(_ session: WalletConnectManager.SessionInfo) {
        Task {
            do {
                try await wcManager.disconnect(topic: session.topic)
            } catch {
                print("Failed to disconnect session: \(error)")
            }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: WalletConnectManager.SessionInfo
    let onDisconnect: () -> Void
    
    private let L = LocalizationManager.shared.t
    
    var body: some View {
        HStack(spacing: 12) {
            // DApp icon
            if let iconUrl = session.iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 44, height: 44)
                .cornerRadius(8)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
                    .frame(width: 44, height: 44)
            }
            
            // Session info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.headline)
                
                if let url = session.url {
                    Text(url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Chains badge
                if !session.chains.isEmpty {
                    Text("\(session.chains.count) chain(s)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Disconnect button
            Button {
                onDisconnect()
            } label: {
                Text(L("ios.walletConnect.disconnect"))
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

struct WalletConnectPairView_Previews: PreviewProvider {
    static var previews: some View {
        WalletConnectPairView()
    }
}
