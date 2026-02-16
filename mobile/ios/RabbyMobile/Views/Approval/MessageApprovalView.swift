import SwiftUI

// MARK: - Message Approval View (personal_sign)

/// Approval view for `personal_sign` (EIP-191) requests.
/// Shows the raw message content, DApp origin, security checks, and sign/reject actions.
///
/// Corresponds to: src/ui/views/Approval/components/SignText.tsx
struct MessageApprovalView: View {
    let message: String               // Raw message (hex string or UTF-8 text)
    let fromAddress: String           // Signing account address
    let origin: String?               // DApp origin URL
    let onApprove: (String) -> Void   // Callback with signature hex
    let onReject: () -> Void          // Reject callback

    @Environment(\.dismiss) private var dismiss
    @StateObject private var securityEngine = SecurityEngineManager.shared
    @StateObject private var keyringManager = KeyringManager.shared

    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var securityResults: [SecurityEngineManager.SecurityCheckResult] = []
    @State private var showError = false

    // MARK: - Computed Properties

    /// Whether the message is a hex-encoded byte string (not human-readable UTF-8).
    private var isHexMessage: Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("0x") else { return false }
        let hexBody = trimmed.dropFirst(2)
        guard !hexBody.isEmpty else { return false }
        return hexBody.allSatisfy { $0.isHexDigit }
    }

    /// Human-readable display text.
    /// If the message is hex, attempt to decode as UTF-8; fall back to raw hex.
    private var displayMessage: String {
        if isHexMessage {
            if let decoded = hexToUTF8(message) {
                return decoded
            }
            return message
        }
        return message
    }

    /// Whether the decoded message is still just hex (could not be decoded to readable text).
    private var showHexWarning: Bool {
        isHexMessage && hexToUTF8(message) == nil
    }

    /// Overall risk level derived from security results.
    private var overallRiskLevel: SecurityEngineManager.RiskLevel {
        if securityResults.contains(where: { $0.level == .forbidden }) { return .forbidden }
        if securityResults.contains(where: { $0.level == .danger }) { return .danger }
        if securityResults.contains(where: { $0.level == .warning }) { return .warning }
        return .safe
    }

    private var hasDangerousRisk: Bool {
        securityResults.contains { $0.level == .danger || $0.level == .forbidden }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. DApp origin info
                        originSection

                        // 2. Security level indicator
                        riskIndicator

                        // 3. Title
                        Text(L("Sign Message"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // 4. Signing account
                        accountSection

                        // 5. Message content
                        messageContentSection

                        // 6. Security check results
                        securityCheckSection
                    }
                    .padding()
                }

                // 7. Bottom action bar
                actionButtons
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    .padding(.top, 8)
                    .background(
                        Color(.systemBackground)
                            .shadow(color: .black.opacity(0.06), radius: 4, y: -2)
                    )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) { rejectMessage() }
                        .foregroundColor(.secondary)
                }
            }
            .alert(L("Signing Error"), isPresented: $showError) {
                Button(L("OK"), role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred.")
            }
        }
        .onAppear { performSecurityCheck() }
    }

    // MARK: - Sections

    /// DApp origin / favicon section.
    private var originSection: some View {
        Group {
            if let origin = origin, !origin.isEmpty {
                HStack(spacing: 10) {
                    // Favicon placeholder (extract host for display)
                    faviconView(for: origin)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(hostName(from: origin))
                            .font(.headline)
                        Text(origin)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    /// Risk level badge at the top.
    private var riskIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(riskColor(overallRiskLevel))
                .frame(width: 10, height: 10)
            Text(riskLabel(overallRiskLevel))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(riskColor(overallRiskLevel))
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    /// Signing account display.
    private var accountSection: some View {
        HStack(spacing: 10) {
            // Identicon placeholder
            Circle()
                .fill(
                    LinearGradient(
                        colors: addressGradientColors(fromAddress),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                if let account = keyringManager.currentAccount, account.address.lowercased() == fromAddress.lowercased() {
                    Text(account.alianName ?? "Account")
                        .font(.subheadline.weight(.medium))
                }
                Text(formatAddress(fromAddress))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    /// Message content area with ScrollView.
    private var messageContentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Message"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if showHexWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(L("This is a hex message and cannot be decoded to readable text."))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            ScrollView {
                Text(displayMessage)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 260)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    /// Security check results list.
    private var securityCheckSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Security Check"))
                    .font(.headline)
                Spacer()
                if securityResults.isEmpty {
                    Label(L("No Issues"), systemImage: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    let dangerCount = securityResults.filter { $0.level == .danger || $0.level == .forbidden }.count
                    if dangerCount > 0 {
                        Label("\(dangerCount) Risk(s)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    } else {
                        Label("\(securityResults.count) Warning(s)", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            }

            ForEach(Array(securityResults), id: \.ruleId) { result in
                HStack(spacing: 8) {
                    Circle()
                        .fill(riskColor(result.level))
                        .frame(width: 8, height: 8)
                    Text(result.message)
                        .font(.caption)
                        .foregroundColor(riskColor(result.level))
                }
            }

            // Always show hex warning in security section when applicable
            if showHexWarning {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text(L("You are signing a hex-encoded message. Verify you trust this DApp."))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    /// Bottom Reject / Sign buttons.
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Reject button
            Button(action: rejectMessage) {
                Text(L("Reject"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray3), lineWidth: 1)
                    )
            }

            // Sign button
            Button(action: signMessage) {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isProcessing ? "Signing..." : "Sign")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(hasDangerousRisk ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isProcessing)
        }
    }

    // MARK: - Actions

    private func performSecurityCheck() {
        Task {
            securityResults = await securityEngine.checkSignMessage(
                from: fromAddress,
                message: message,
                origin: origin
            )
        }
    }

    private func signMessage() {
        isProcessing = true
        Task {
            do {
                // Prepare message data for personal_sign (EIP-191)
                let messageData: Data
                if isHexMessage {
                    // Strip 0x prefix and convert hex to bytes
                    let hexBody = String(message.dropFirst(2))
                    messageData = Data(hexString: hexBody) ?? Data(message.utf8)
                } else {
                    messageData = Data(message.utf8)
                }

                let signatureData = try await keyringManager.signMessage(
                    address: fromAddress,
                    message: messageData
                )
                let signatureHex = "0x" + signatureData.map { String(format: "%02x", $0) }.joined()
                onApprove(signatureHex)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isProcessing = false
        }
    }

    private func rejectMessage() {
        onReject()
        dismiss()
    }

    // MARK: - Helpers

    private func formatAddress(_ addr: String) -> String {
        guard addr.count > 10 else { return addr }
        return "\(addr.prefix(6))...\(addr.suffix(4))"
    }

    private func hexToUTF8(_ hex: String) -> String? {
        var hexStr = hex
        if hexStr.hasPrefix("0x") { hexStr = String(hexStr.dropFirst(2)) }
        guard hexStr.count % 2 == 0 else { return nil }

        var bytes: [UInt8] = []
        var index = hexStr.startIndex
        while index < hexStr.endIndex {
            let nextIndex = hexStr.index(index, offsetBy: 2)
            guard let byte = UInt8(hexStr[index..<nextIndex], radix: 16) else { return nil }
            bytes.append(byte)
            index = nextIndex
        }

        let decoded = String(bytes: bytes, encoding: .utf8)
        // Only return if it looks like readable text (no control chars except newline/tab)
        if let decoded = decoded {
            let hasControlChars = decoded.unicodeScalars.contains {
                CharacterSet.controlCharacters
                    .subtracting(CharacterSet.newlines)
                    .subtracting(CharacterSet(charactersIn: "\t"))
                    .contains($0)
            }
            if hasControlChars { return nil }
        }
        return decoded
    }

    private func hostName(from urlString: String) -> String {
        if let url = URL(string: urlString), let host = url.host {
            return host
        }
        return urlString
    }

    private func faviconView(for origin: String) -> some View {
        Group {
            if let url = URL(string: origin),
               let host = url.host,
               let faviconURL = URL(string: "https://\(host)/favicon.ico") {
                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .frame(width: 36, height: 36)
                            .cornerRadius(8)
                    default:
                        defaultFaviconPlaceholder
                    }
                }
            } else {
                defaultFaviconPlaceholder
            }
        }
    }

    private var defaultFaviconPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
            )
    }

    private func riskColor(_ level: SecurityEngineManager.RiskLevel) -> Color {
        switch level {
        case .safe: return .green
        case .warning: return .orange
        case .danger, .forbidden: return .red
        }
    }

    private func riskLabel(_ level: SecurityEngineManager.RiskLevel) -> String {
        switch level {
        case .safe: return "Low Risk"
        case .warning: return "Medium Risk"
        case .danger: return "High Risk"
        case .forbidden: return "Forbidden"
        }
    }

    /// Generate deterministic gradient colors from an address for identicon placeholder.
    private func addressGradientColors(_ address: String) -> [Color] {
        let hash = address.lowercased().dropFirst(2).prefix(6)
        let r = Double(UInt8(hash.prefix(2), radix: 16) ?? 128) / 255.0
        let g = Double(UInt8(hash.dropFirst(2).prefix(2), radix: 16) ?? 128) / 255.0
        let b = Double(UInt8(hash.dropFirst(4).prefix(2), radix: 16) ?? 128) / 255.0
        return [Color(red: r, green: g, blue: b), Color(red: b, green: r, blue: g)]
    }
}
