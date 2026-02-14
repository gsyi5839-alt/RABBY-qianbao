import SwiftUI

/// Scam transaction filter and detection
/// Corresponds to: src/ui/views/TransactionHistory scam filter
@MainActor
class ScamFilterManager: ObservableObject {
    static let shared = ScamFilterManager()

    @Published var isScamFilterEnabled: Bool {
        didSet { UserDefaults.standard.set(isScamFilterEnabled, forKey: "scamFilterEnabled") }
    }
    @Published var scamAddresses: Set<String> = []
    @Published var safeMarked: Set<String> = []

    private init() {
        self.isScamFilterEnabled = UserDefaults.standard.bool(forKey: "scamFilterEnabled")
        if !UserDefaults.standard.bool(forKey: "scamFilterInitialized") {
            self.isScamFilterEnabled = true
            UserDefaults.standard.set(true, forKey: "scamFilterEnabled")
            UserDefaults.standard.set(true, forKey: "scamFilterInitialized")
        }
    }

    enum ScamType: String {
        case phishing = "Phishing"
        case dustAttack = "Dust Attack"
        case fakeToken = "Fake Token"
        case honeypot = "Honeypot"
        case other = "Suspicious"
    }

    struct ScamCheckResult {
        let isScam: Bool
        let type: ScamType
        let reason: String
    }

    func checkTransaction(_ tx: ScamCheckableTransaction) -> ScamCheckResult? {
        // Check safe-marked
        if safeMarked.contains(tx.hash) { return nil }

        // Check API is_scam flag
        if tx.isScam {
            return ScamCheckResult(isScam: true, type: .phishing, reason: "Flagged as scam by security service")
        }

        // Check known scam addresses
        if scamAddresses.contains(tx.from.lowercased()) {
            return ScamCheckResult(isScam: true, type: .phishing, reason: "Known scam address")
        }

        // Check zero-value token transfer (dust attack)
        if tx.value == "0" && tx.tokenTransfers.contains(where: { $0.amount == "0" || Double($0.amount) ?? 1 < 0.001 }) {
            return ScamCheckResult(isScam: true, type: .dustAttack, reason: "Zero-value token transfer (potential dust attack)")
        }

        return nil
    }

    func filterTransactions(_ txs: [ScamCheckableTransaction]) -> [ScamCheckableTransaction] {
        guard isScamFilterEnabled else { return txs }
        return txs.filter { checkTransaction($0) == nil }
    }

    func markAsSafe(_ txHash: String) {
        safeMarked.insert(txHash)
    }

    func reportScam(_ txHash: String) {
        // Placeholder for API report
    }

    func hiddenCount(in txs: [ScamCheckableTransaction]) -> Int {
        guard isScamFilterEnabled else { return 0 }
        return txs.count - filterTransactions(txs).count
    }
}

// MARK: - Scam Filter Toggle

struct ScamFilterToggle: View {
    @StateObject private var manager = ScamFilterManager.shared
    let totalTransactions: [ScamCheckableTransaction]

    var body: some View {
        HStack {
            Image(systemName: "shield.fill")
                .foregroundColor(manager.isScamFilterEnabled ? .green : .secondary)

            Toggle(L("Hide scam transactions"), isOn: $manager.isScamFilterEnabled)
                .font(.subheadline)

            if manager.isScamFilterEnabled {
                let hidden = manager.hiddenCount(in: totalTransactions)
                if hidden > 0 {
                    Text("\(hidden) hidden")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }
        }
    }
}

// MARK: - Scam Transaction Badge

struct ScamTransactionBadge: View {
    let result: ScamFilterManager.ScamCheckResult
    let txHash: String
    @StateObject private var manager = ScamFilterManager.shared
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                Text(result.type.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .cornerRadius(6)
        }
        .alert(L("Potential Scam"), isPresented: $showDetail) {
            Button(L("Mark as Safe")) { manager.markAsSafe(txHash) }
            Button(L("Report")) { manager.reportScam(txHash) }
            Button(L("Close"), role: .cancel) {}
        } message: {
            Text(result.reason + "\n\nDo not interact with the sender address.")
        }
    }
}

// MARK: - Scam-checkable Transaction Model (minimal for scam checking)

struct ScamCheckableTransaction {
    let hash: String
    let from: String
    let to: String
    let value: String
    let isScam: Bool
    let tokenTransfers: [ScamTokenTransfer]
}

struct ScamTokenTransfer {
    let token: String
    let amount: String
    let from: String
    let to: String
}
