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
                        Text("You can only reset your password if you have your seed phrase. This will restore your wallet with the new password.")
                            .font(.subheadline).foregroundColor(.orange)
                    }
                    .padding().background(Color.orange.opacity(0.1)).cornerRadius(8)
                    
                    // Seed phrase
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter Seed Phrase").font(.headline)
                        TextEditor(text: $seedPhrase)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .autocapitalization(.none)
                        Text("Enter your 12 or 24 word seed phrase, separated by spaces")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    
                    // New password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Password").font(.headline)
                        SecureField("Enter new password", text: $newPassword)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Confirm new password", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                        
                        if newPassword.count > 0 && newPassword.count < 8 {
                            Text("Password must be at least 8 characters").font(.caption).foregroundColor(.red)
                        }
                        if !confirmPassword.isEmpty && newPassword != confirmPassword {
                            Text("Passwords do not match").font(.caption).foregroundColor(.red)
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                    
                    // Restore button
                    Button(action: restoreWallet) {
                        if isRestoring {
                            HStack { ProgressView().tint(.white); Text("Restoring...") }
                        } else {
                            Text("Reset Password & Restore")
                        }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(isValid ? Color.blue : Color.gray)
                    .foregroundColor(.white).cornerRadius(12)
                    .disabled(!isValid || isRestoring)
                }
                .padding()
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .alert("Wallet Restored", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your wallet has been restored with the new password.")
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
                    Text("No signed messages").foregroundColor(.secondary)
                    Text("Messages you sign from DApps will appear here").font(.caption).foregroundColor(.gray)
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
        .navigationTitle("Signed Messages")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !records.isEmpty {
                    Button("Clear All") { clearHistory() }.foregroundColor(.red)
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

/// NFT Approval View - Manage NFT approvals
/// Corresponds to: src/ui/views/NFTApproval/
struct NFTApprovalView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var approvals: [NFTApprovalItem] = []
    @State private var isLoading = false
    
    struct NFTApprovalItem: Identifiable {
        let id: String
        let collectionName: String
        let spender: String
        let spenderName: String?
        let isApprovedForAll: Bool
        let chain: String
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading NFT approvals...")
            } else if approvals.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield").font(.system(size: 48)).foregroundColor(.green)
                    Text("No NFT approvals").foregroundColor(.secondary)
                }
            } else {
                List(approvals) { approval in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(approval.collectionName).fontWeight(.medium)
                            Text("Spender: \(approval.spenderName ?? String(approval.spender.prefix(10)) + "...")")
                                .font(.caption).foregroundColor(.secondary)
                            if approval.isApprovedForAll {
                                Text("Approved for All")
                                    .font(.caption2).foregroundColor(.red)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.red.opacity(0.1)).cornerRadius(4)
                            }
                        }
                        Spacer()
                        Button("Revoke") { revokeApproval(approval) }
                            .font(.caption).foregroundColor(.red)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("NFT Approvals")
        .onAppear { loadApprovals() }
    }
    
    private func loadApprovals() {
        guard let address = keyringManager.currentAccount?.address else { return }
        isLoading = true
        Task {
            do {
                let results = try await OpenAPIService.shared.getNFTApprovals(address: address)
                approvals = results.map { item in
                    NFTApprovalItem(
                        id: item.spender.id, collectionName: item.token.symbol,
                        spender: item.spender.id, spenderName: item.spender.name,
                        isApprovedForAll: item.value == "unlimited", chain: item.token.chain
                    )
                }
            } catch { print("Failed to load NFT approvals: \(error)") }
            isLoading = false
        }
    }
    
    private func revokeApproval(_ approval: NFTApprovalItem) {
        // Revoke by calling setApprovalForAll(spender, false)
    }
}

/// QR Code Generator View - Shows address as QR code for receiving
struct QRCodeGeneratorView: View {
    let address: String
    let chainName: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // QR Code
                if let qrImage = generateQRCode(from: address) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 250, height: 250)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 8)
                }
                
                // Chain info
                if let chain = chainName {
                    Text(chain).font(.subheadline).foregroundColor(.secondary)
                }
                
                // Address
                VStack(spacing: 8) {
                    Text("Your Address").font(.headline)
                    Text(address)
                        .font(.system(.caption, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Copy button
                Button(action: { UIPasteboard.general.string = address }) {
                    Label("Copy Address", systemImage: "doc.on.doc")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Share button
                Button(action: shareAddress) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                        .background(Color(.systemGray6)).foregroundColor(.primary).cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let scale = 250.0 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    private func shareAddress() {
        let activityVC = UIActivityViewController(activityItems: [address], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

/// Select To Address View - Address book for sending
/// Corresponds to: src/ui/views/SelectToAddress/
struct SelectToAddressView: View {
    @StateObject private var contactBook = ContactBookManager.shared
    @StateObject private var prefManager = PreferenceManager.shared
    @StateObject private var whitelistManager = WhitelistManager.shared
    @Binding var selectedAddress: String
    @State private var searchText = ""
    @State private var selectedTab = 0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                TextField("Search address or name", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                // Tabs
                Picker("", selection: $selectedTab) {
                    Text("Recent").tag(0)
                    Text("Contacts").tag(1)
                    Text("My Addresses").tag(2)
                    Text("Whitelist").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Content
                List {
                    switch selectedTab {
                    case 0: recentAddresses
                    case 1: contactAddresses
                    case 2: myAddresses
                    case 3: whitelistedAddresses
                    default: EmptyView()
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
    
    private var recentAddresses: some View {
        ForEach(contactBook.contacts.filter { matchesSearch($0.address, $0.name) }, id: \.address) { contact in
            addressRow(address: contact.address, name: contact.name)
        }
    }
    
    private var contactAddresses: some View {
        ForEach(contactBook.contacts.filter { matchesSearch($0.address, $0.name) }, id: \.address) { contact in
            addressRow(address: contact.address, name: contact.name)
        }
    }
    
    private var myAddresses: some View {
        ForEach(prefManager.accounts.filter { matchesSearch($0.address, $0.aliasName) }) { account in
            addressRow(address: account.address, name: account.aliasName)
        }
    }
    
    private var whitelistedAddresses: some View {
        ForEach(whitelistManager.whitelistedAddresses, id: \.self) { address in
            addressRow(address: address, name: nil)
        }
    }
    
    private func addressRow(address: String, name: String?) -> some View {
        Button(action: {
            selectedAddress = address
            dismiss()
        }) {
            HStack {
                Circle().fill(Color.blue.opacity(0.2)).frame(width: 32, height: 32)
                    .overlay(Text(String(address.dropFirst(2).prefix(2))).font(.caption2).fontWeight(.bold).foregroundColor(.blue))
                VStack(alignment: .leading) {
                    if let name = name, !name.isEmpty {
                        Text(name).font(.subheadline).foregroundColor(.primary)
                    }
                    Text(address).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
            }
        }
    }
    
    private func matchesSearch(_ address: String, _ name: String?) -> Bool {
        if searchText.isEmpty { return true }
        let query = searchText.lowercased()
        return address.lowercased().contains(query) || (name?.lowercased().contains(query) ?? false)
    }
}

/// Rabby Points View
/// Corresponds to: src/ui/views/RabbyPoints/
struct RabbyPointsView: View {
    @StateObject private var pointsManager = RabbyPointsManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var isClaiming = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Points card
                VStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60)).foregroundColor(.orange)
                    Text("\(pointsManager.totalPoints)")
                        .font(.system(size: 48, weight: .bold))
                    Text("Rabby Points")
                        .font(.subheadline).foregroundColor(.secondary)
                    
                    if let rank = pointsManager.rank {
                        Text("Rank #\(rank)")
                            .font(.caption).foregroundColor(.blue)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1)).cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(LinearGradient(colors: [.orange.opacity(0.1), .yellow.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(16)
                
                // Claim button
                Button(action: claimPoints) {
                    if isClaiming {
                        HStack { ProgressView().tint(.white); Text("Claiming...") }
                    } else {
                        Label("Claim Daily Points", systemImage: "gift.fill")
                    }
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.orange).foregroundColor(.white).cornerRadius(12)
                .disabled(isClaiming)
                
                // Referral
                if let link = pointsManager.getReferralLink() {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite Friends").font(.headline)
                        Text("Share your referral link to earn bonus points")
                            .font(.caption).foregroundColor(.secondary)
                        
                        HStack {
                            Text(link).font(.caption).foregroundColor(.blue).lineLimit(1)
                            Spacer()
                            Button(action: { UIPasteboard.general.string = link }) {
                                Image(systemName: "doc.on.doc").foregroundColor(.blue)
                            }
                        }
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                    }
                    .padding().background(Color(.systemBackground)).cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4)
                }
                
                // History
                if !pointsManager.claimHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Claim History").font(.headline)
                        ForEach(pointsManager.claimHistory.prefix(10)) { record in
                            HStack {
                                Image(systemName: "star.fill").foregroundColor(.orange)
                                Text("+\(record.points) pts").fontWeight(.medium)
                                Text("(\(record.type))").font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text(record.claimedAt, style: .relative).font(.caption).foregroundColor(.gray)
                            }
                        }
                    }
                    .padding().background(Color(.systemGray6)).cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Rabby Points")
        .onAppear { loadPoints() }
    }
    
    private func loadPoints() {
        guard let address = keyringManager.currentAccount?.address else { return }
        Task { await pointsManager.loadPoints(address: address) }
    }
    
    private func claimPoints() {
        guard let address = keyringManager.currentAccount?.address else { return }
        isClaiming = true
        Task {
            _ = try? await pointsManager.claimDailyPoints(address: address)
            isClaiming = false
        }
    }
}
