import SwiftUI

/// EIP-712 TypedData signing approval view
/// Corresponds to: src/ui/views/Approval/components/SignTypedData
struct TypedDataApprovalView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var keyringManager = KeyringManager.shared

    let typedData: EIP712TypedDataView
    let origin: String?
    let siteName: String?
    let iconUrl: String?
    var onApprove: ((String) -> Void)?
    var onReject: (() -> Void)?

    @State private var isProcessing = false
    @State private var showSecurityWarning = false
    @State private var expandedTypes: Set<String> = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    dappInfoSection
                    domainSection
                    warningSection
                    messageSection
                    actionButtons
                }
                .padding()
            }
            .navigationTitle(L("Sign Typed Data"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Reject")) { rejectSigning() }
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - DApp Info

    private var dappInfoSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if let iconUrl = iconUrl, let url = URL(string: iconUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().frame(width: 40, height: 40).cornerRadius(8)
                    } placeholder: { Color.gray.frame(width: 40, height: 40).cornerRadius(8) }
                }
                VStack(alignment: .leading) {
                    Text(siteName ?? "Unknown DApp").font(.headline)
                    if let origin = origin {
                        Text(origin).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Domain Info

    private var domainSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Domain")).font(.headline)

            if let name = typedData.domain.name {
                infoRow("Name", name)
            }
            if let version = typedData.domain.version {
                infoRow("Version", version)
            }
            if let chainId = typedData.domain.chainId {
                infoRow("Chain ID", "\(chainId)")
            }
            if let contract = typedData.domain.verifyingContract {
                infoRow("Contract", EthereumUtil.truncateAddress(contract))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Security Warnings

    @ViewBuilder
    private var warningSection: some View {
        let warnings = analyzeWarnings()
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(warnings, id: \.self) { warning in
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(warning)
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Message Fields

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Message")).font(.headline)
                Spacer()
                Text(typedData.primaryType)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }

            Divider()

            renderMessageFields(typedData.message, typeName: typedData.primaryType, depth: 0)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func renderMessageFields(_ fields: [String: AnyJSON], typeName: String, depth: Int) -> some View {
        let typeFields = typedData.types[typeName] ?? []

        ForEach(Array(typeFields.enumerated()), id: \.offset) { _, field in
            let value = fields[field.name]
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(field.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, CGFloat(depth * 16))
                    Spacer()
                    if isHighlightField(field.name) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                if let value = value {
                    Text(formatValue(value, type: field.type))
                        .font(.system(.body, design: .monospaced))
                        .padding(.leading, CGFloat(depth * 16))
                        .lineLimit(3)
                }
            }

            if depth < 3 { Divider() }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { approveSigning() }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isProcessing ? "Signing..." : "Approve & Sign")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isProcessing ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isProcessing)

            Button(L("Reject")) { rejectSigning() }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).lineLimit(1)
        }
    }

    private func isHighlightField(_ name: String) -> Bool {
        let watchFields = ["spender", "operator", "deadline", "expiry", "nonce", "value", "amount", "allowed"]
        return watchFields.contains(name.lowercased())
    }

    private func formatValue(_ value: AnyJSON, type: String) -> String {
        switch value {
        case .string(let s): return s
        case .number(let n): return type.contains("uint") ? formatTokenAmount(n) : "\(n)"
        case .bool(let b): return b ? "true" : "false"
        default: return "\(value)"
        }
    }

    private func formatTokenAmount(_ amount: Double) -> String {
        if amount > 1e18 {
            return String(format: "%.4f (× 10¹⁸)", amount / 1e18)
        }
        return String(format: "%.0f", amount)
    }

    private func analyzeWarnings() -> [String] {
        var warnings: [String] = []

        // Check for Permit/Permit2 signatures
        if typedData.primaryType == "Permit" || typedData.primaryType == "PermitSingle" || typedData.primaryType == "PermitBatch" {
            warnings.append("This is a token spending permit. Signing allows the spender to use your tokens.")
        }

        // Check for unknown contract
        if let contract = typedData.domain.verifyingContract {
            if !EthereumUtil.isValidAddress(contract) {
                warnings.append("Invalid verifying contract address.")
            }
        }

        // Check deadline
        if let deadline = typedData.message["deadline"] {
            if case .number(let d) = deadline, d > 1e12 {
                warnings.append("Very long expiry. This approval may be valid indefinitely.")
            }
        }

        return warnings
    }

    private func approveSigning() {
        isProcessing = true
        Task {
            do {
                guard let address = keyringManager.currentAccount?.address else {
                    throw EthereumError.invalidAddress
                }
                let typedDataJSON = typedData.toJSONString()
                let signatureData = try await keyringManager.signTypedData(address: address, typedData: typedDataJSON)
                let signatureHex = "0x" + signatureData.map { String(format: "%02x", $0) }.joined()
                await MainActor.run {
                    isProcessing = false
                    onApprove?(signatureHex)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }

    private func rejectSigning() {
        onReject?()
        dismiss()
    }
}

// MARK: - EIP-712 Data Models (View Layer)
// Note: Using custom types here to avoid conflicts with Core/EthereumUtils.swift
// These are simplified view-layer models for UI rendering

struct EIP712TypedDataView {
    let types: [String: [EIP712FieldView]]
    let primaryType: String
    let domain: EIP712DomainView
    let message: [String: AnyJSON]

    /// Serialize to a JSON string suitable for EIP-712 signing via KeyringManager.
    func toJSONString() -> String {
        var typesDict: [String: [[String: String]]] = [:]
        for (key, fields) in types {
            typesDict[key] = fields.map { ["name": $0.name, "type": $0.type] }
        }

        var domainDict: [String: Any] = [:]
        if let name = domain.name { domainDict["name"] = name }
        if let version = domain.version { domainDict["version"] = version }
        if let chainId = domain.chainId { domainDict["chainId"] = chainId }
        if let contract = domain.verifyingContract { domainDict["verifyingContract"] = contract }
        if let salt = domain.salt { domainDict["salt"] = salt }

        let messageDict = message.mapValues { $0.toJSONObject() }

        let root: [String: Any] = [
            "types": typesDict,
            "primaryType": primaryType,
            "domain": domainDict,
            "message": messageDict
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
}

struct EIP712FieldView {
    let name: String
    let type: String
}

struct EIP712DomainView {
    let name: String?
    let version: String?
    let chainId: Int?
    let verifyingContract: String?
    let salt: String?
}

enum AnyJSON: Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([AnyJSON])
    case object([String: AnyJSON])
    case null

    /// Convert to a Foundation object suitable for JSONSerialization.
    func toJSONObject() -> Any {
        switch self {
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .array(let arr): return arr.map { $0.toJSONObject() }
        case .object(let dict): return dict.mapValues { $0.toJSONObject() }
        case .null: return NSNull()
        }
    }

    static func from(_ any: Any) -> AnyJSON {
        switch any {
        case let s as String: return .string(s)
        case let n as NSNumber: return .number(n.doubleValue)
        case let b as Bool: return .bool(b)
        case let arr as [Any]: return .array(arr.map { AnyJSON.from($0) })
        case let dict as [String: Any]: return .object(dict.mapValues { AnyJSON.from($0) })
        default: return .null
        }
    }
}
