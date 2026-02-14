import SwiftUI

// MARK: - Security Rule Models

enum SecurityRuleLevel: String, CaseIterable {
    case safe, warning, danger, forbidden

    var color: Color {
        switch self {
        case .safe: return .green
        case .warning: return .orange
        case .danger: return .red
        case .forbidden: return .black
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.shield.fill"
        case .forbidden: return "nosign"
        }
    }
}

enum SecurityRuleType: String {
    case contractSecurity, tokenSecurity, addressSecurity, signatureSecurity, transactionSecurity
}

struct SecurityRule: Identifiable {
    let id: String
    let level: SecurityRuleLevel
    let title: String
    let description: String
    let ruleType: SecurityRuleType
    let learnMoreURL: String?

    init(id: String, level: SecurityRuleLevel, title: String, description: String, ruleType: SecurityRuleType, learnMoreURL: String? = nil) {
        self.id = id
        self.level = level
        self.title = title
        self.description = description
        self.ruleType = ruleType
        self.learnMoreURL = learnMoreURL
    }
}

// MARK: - Security Rule Drawer (Bottom Sheet)

struct SecurityRuleDrawer: View {
    let rule: SecurityRule
    @Environment(\.dismiss) var dismiss
    @State private var showExplanation = false

    var body: some View {
        VStack(spacing: 20) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            // Header
            HStack(spacing: 12) {
                Image(systemName: rule.level.icon)
                    .font(.title2)
                    .foregroundColor(rule.level.color)
                    .frame(width: 44, height: 44)
                    .background(rule.level.color.opacity(0.15))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.title)
                        .font(.headline)
                    Text(rule.ruleType.rawValue.replacingOccurrences(of: "Security", with: " Security"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Description
            Text(rule.description)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Danger/Forbidden warning
            if rule.level == .danger || rule.level == .forbidden {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text(rule.level == .forbidden ? L("security_action_blocked") : L("security_proceed_caution"))
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(12)
            }

            // Expandable explanation
            DisclosureGroup(L("security_what_does_mean"), isExpanded: $showExplanation) {
                Text(explanationText(for: rule))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Learn more
            if let urlString = rule.learnMoreURL, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "book.fill")
                        Text(L("learn_more"))
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }

            Spacer()

            Button(L("close")) { dismiss() }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
        }
        .padding()
    }

    private func explanationText(for rule: SecurityRule) -> String {
        switch rule.ruleType {
        case .contractSecurity:
            return LocalizationManager.shared.t("security_contract_explain")
        case .tokenSecurity:
            return LocalizationManager.shared.t("security_token_explain")
        case .addressSecurity:
            return LocalizationManager.shared.t("security_address_explain")
        case .signatureSecurity:
            return LocalizationManager.shared.t("security_signature_explain")
        case .transactionSecurity:
            return LocalizationManager.shared.t("security_transaction_explain")
        }
    }
}

// MARK: - Security Check List (Reusable Component)

struct SecurityCheckListView: View {
    let results: [SecurityCheckResult]
    @State private var selectedRule: SecurityRule?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("security_check")).font(.headline)

            ForEach(results) { result in
                Button(action: { selectedRule = result.rule }) {
                    HStack(spacing: 8) {
                        Image(systemName: result.rule.level.icon)
                            .foregroundColor(result.rule.level.color)
                            .font(.subheadline)

                        Text(result.rule.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(item: $selectedRule) { rule in
            SecurityRuleDrawer(rule: rule)
                .modifier(SheetPresentationModifier(detents: [.medium]))
        }
    }
}

struct SecurityCheckResult: Identifiable {
    var id: String { rule.id }
    let rule: SecurityRule
    let passed: Bool
}
