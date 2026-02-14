import SwiftUI
import Combine

// MARK: - Bridge History Item Model

struct BridgeHistoryItem: Codable, Identifiable, Equatable {
    let id: String
    let fromChain: BridgeChainInfo
    let toChain: BridgeChainInfo
    let fromToken: BridgeTokenInfo
    let toToken: BridgeTokenInfo
    let amount: String
    let toAmount: String
    let provider: String
    let providerName: String
    let providerLogo: String?
    var status: BridgeHistoryStatus
    let txHash: String
    var destinationTxHash: String?
    let createdAt: Date
    var completedAt: Date?

    static func == (lhs: BridgeHistoryItem, rhs: BridgeHistoryItem) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.destinationTxHash == rhs.destinationTxHash
    }
}

struct BridgeChainInfo: Codable, Equatable {
    let id: Int
    let serverId: String
    let name: String
    let symbol: String
    let scanUrl: String
    let logo: String
}

struct BridgeTokenInfo: Codable, Equatable {
    let symbol: String
    let address: String
    let decimals: Int
    let logo: String?
}

// MARK: - Bridge History Status

enum BridgeHistoryStatus: String, Codable, CaseIterable, Equatable {
    case pending
    case sourceConfirmed
    case bridging
    case destinationConfirmed
    case completed
    case failed

    var displayText: String {
        switch self {
        case .pending: return "Pending"
        case .sourceConfirmed: return "Source Confirmed"
        case .bridging: return "Bridging"
        case .destinationConfirmed: return "Destination Confirmed"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock.fill"
        case .sourceConfirmed: return "checkmark.circle"
        case .bridging: return "arrow.left.arrow.right"
        case .destinationConfirmed: return "checkmark.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .sourceConfirmed: return .blue
        case .bridging: return .purple
        case .destinationConfirmed: return .cyan
        case .completed: return .green
        case .failed: return .red
        }
    }

    /// 0-based step index for the 4-step progress bar
    /// Steps: Source Confirmed -> Bridging -> Destination Confirmed -> Completed
    var stepIndex: Int {
        switch self {
        case .pending: return 0
        case .sourceConfirmed: return 1
        case .bridging: return 2
        case .destinationConfirmed: return 3
        case .completed: return 4
        case .failed: return -1
        }
    }

    var isTerminal: Bool {
        self == .completed || self == .failed
    }
}

// MARK: - Bridge History Manager

/// Manages bridge transaction history persistence and status polling.
/// Stores history items in StorageManager and auto-polls pending items every 30s.
@MainActor
class BridgeHistoryManager: ObservableObject {
    static let shared = BridgeHistoryManager()

    @Published var historyItems: [BridgeHistoryItem] = []
    @Published var isRefreshing = false

    private let storage = StorageManager.shared
    private let bridgeManager = BridgeManager.shared
    private let storageKey = "rabby_bridge_history"
    private var pollTimer: Timer?
    private var pollTask: Task<Void, Never>?

    private init() {
        loadHistory()
        startAutoPoll()
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Public API

    /// Add a new bridge transaction to history
    func addBridgeTransaction(
        quote: BridgeManager.BridgeQuote,
        txHash: String,
        fromChain: Chain,
        toChain: Chain
    ) {
        let item = BridgeHistoryItem(
            id: UUID().uuidString,
            fromChain: BridgeChainInfo(
                id: fromChain.id,
                serverId: fromChain.serverId,
                name: fromChain.name,
                symbol: fromChain.symbol,
                scanUrl: fromChain.scanUrl,
                logo: fromChain.logo
            ),
            toChain: BridgeChainInfo(
                id: toChain.id,
                serverId: toChain.serverId,
                name: toChain.name,
                symbol: toChain.symbol,
                scanUrl: toChain.scanUrl,
                logo: toChain.logo
            ),
            fromToken: BridgeTokenInfo(
                symbol: quote.fromToken.symbol,
                address: quote.fromToken.address,
                decimals: quote.fromToken.decimals,
                logo: quote.fromToken.logo
            ),
            toToken: BridgeTokenInfo(
                symbol: quote.toToken.symbol,
                address: quote.toToken.address,
                decimals: quote.toToken.decimals,
                logo: quote.toToken.logo
            ),
            amount: quote.fromAmount,
            toAmount: quote.toAmount,
            provider: quote.aggregatorId,
            providerName: quote.aggregatorName,
            providerLogo: quote.aggregatorLogo,
            status: .pending,
            txHash: txHash,
            destinationTxHash: nil,
            createdAt: Date(),
            completedAt: nil
        )

        historyItems.insert(item, at: 0)
        saveHistory()
    }

    /// Refresh all pending bridge statuses
    func refreshPendingStatuses() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let pendingItems = historyItems.filter { !$0.status.isTerminal }

        await withTaskGroup(of: (String, BridgeHistoryStatus, String?)?.self) { group in
            for item in pendingItems {
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    return await self.fetchStatusUpdate(for: item)
                }
            }

            for await result in group {
                guard let (itemId, newStatus, destTxHash) = result else { continue }
                if let index = historyItems.firstIndex(where: { $0.id == itemId }) {
                    historyItems[index].status = newStatus
                    if let hash = destTxHash {
                        historyItems[index].destinationTxHash = hash
                    }
                    if newStatus.isTerminal {
                        historyItems[index].completedAt = Date()
                    }
                }
            }
        }

        saveHistory()
    }

    /// Remove a single history item
    func removeItem(_ item: BridgeHistoryItem) {
        historyItems.removeAll { $0.id == item.id }
        saveHistory()
    }

    /// Clear all history
    func clearHistory() {
        historyItems.removeAll()
        saveHistory()
    }

    /// Get count of pending (non-terminal) bridges
    var pendingCount: Int {
        historyItems.filter { !$0.status.isTerminal }.count
    }

    // MARK: - Private

    private func fetchStatusUpdate(for item: BridgeHistoryItem) async -> (String, BridgeHistoryStatus, String?)? {
        // Build a minimal Chain for the API call
        let chain = Chain(
            id: item.fromChain.id,
            name: item.fromChain.name,
            serverId: item.fromChain.serverId,
            symbol: item.fromChain.symbol,
            nativeTokenAddress: "0x0000000000000000000000000000000000000000",
            rpcUrl: ChainManager.shared.getRPCUrl(chain: item.fromChain.serverId),
            scanUrl: item.fromChain.scanUrl,
            logo: item.fromChain.logo
        )

        do {
            let status = try await bridgeManager.getBridgeStatus(txHash: item.txHash, fromChain: chain)
            let newStatus = mapAPIStatus(status.status, currentStatus: item.status)
            return (item.id, newStatus, status.toTxHash)
        } catch {
            print("[BridgeHistoryManager] Failed to fetch status for \(item.txHash): \(error)")
            return nil
        }
    }

    /// Map API status string to our detailed BridgeHistoryStatus enum
    private func mapAPIStatus(_ apiStatus: String, currentStatus: BridgeHistoryStatus) -> BridgeHistoryStatus {
        switch apiStatus.lowercased() {
        case "success", "completed", "done":
            return .completed
        case "failed", "error", "refunded":
            return .failed
        case "bridging", "in_progress":
            // If we were previously sourceConfirmed, move to bridging
            return .bridging
        case "source_confirmed", "source_completed":
            return .sourceConfirmed
        case "destination_confirmed", "dest_confirmed":
            return .destinationConfirmed
        default:
            // Keep current status if we cannot determine the new one
            if currentStatus == .pending {
                return .sourceConfirmed
            }
            return currentStatus
        }
    }

    private func loadHistory() {
        if let data = storage.getData(forKey: storageKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            if let items = try? decoder.decode([BridgeHistoryItem].self, from: data) {
                historyItems = items
            }
        }
    }

    private func saveHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        if let data = try? encoder.encode(historyItems) {
            storage.setData(data, forKey: storageKey)
        }
    }

    /// Start auto-polling pending bridge statuses every 30 seconds
    private func startAutoPoll() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                let hasPending = self.historyItems.contains { !$0.status.isTerminal }
                if hasPending {
                    await self.refreshPendingStatuses()
                }
            }
        }
    }
}

// MARK: - BridgeHistoryView

/// Displays a list of bridge transactions with status tracking, pull-to-refresh,
/// and detail drill-down for source/destination transaction links.
struct BridgeHistoryView: View {
    @StateObject private var historyManager = BridgeHistoryManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: BridgeHistoryItem?
    @State private var showDetail = false
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationView {
            Group {
                if historyManager.historyItems.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle(L("Bridge History"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !historyManager.historyItems.isEmpty {
                        Menu {
                            Button(role: .destructive, action: { showClearConfirmation = true }) {
                                Label(L("Clear History"), systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .alert(L("Clear Bridge History?"), isPresented: $showClearConfirmation) {
                Button(L("Cancel"), role: .cancel) {}
                Button(L("Clear All"), role: .destructive) {
                    historyManager.clearHistory()
                }
            } message: {
                Text(L("This will remove all bridge transaction history. This action cannot be undone."))
            }
            .sheet(isPresented: $showDetail) {
                if let item = selectedItem {
                    BridgeHistoryDetailSheet(item: item)
                }
            }
        }
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            // Pending section
            let pendingItems = historyManager.historyItems.filter { !$0.status.isTerminal }
            if !pendingItems.isEmpty {
                Section {
                    ForEach(pendingItems) { item in
                        historyRow(item: item)
                            .onTapGesture {
                                selectedItem = item
                                showDetail = true
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            historyManager.removeItem(pendingItems[index])
                        }
                    }
                } header: {
                    HStack {
                        Text(L("In Progress"))
                        Spacer()
                        if historyManager.isRefreshing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
            }

            // Completed section
            let completedItems = historyManager.historyItems.filter { $0.status.isTerminal }
            if !completedItems.isEmpty {
                Section(L("Completed")) {
                    ForEach(completedItems) { item in
                        historyRow(item: item)
                            .onTapGesture {
                                selectedItem = item
                                showDetail = true
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            historyManager.removeItem(completedItems[index])
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await historyManager.refreshPendingStatuses()
        }
    }

    // MARK: - History Row

    private func historyRow(item: BridgeHistoryItem) -> some View {
        VStack(spacing: 10) {
            // Top row: chains + amount
            HStack(spacing: 8) {
                // From chain
                VStack(spacing: 2) {
                    chainIcon(name: item.fromChain.name, logo: item.fromChain.logo)
                    Text(item.fromChain.symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // To chain
                VStack(spacing: 2) {
                    chainIcon(name: item.toChain.name, logo: item.toChain.logo)
                    Text(item.toChain.symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Amount
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(formatAmount(item.amount)) \(item.fromToken.symbol)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("-> \(formatAmount(item.toAmount)) \(item.toToken.symbol)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Status progress bar (4 steps)
            bridgeProgressBar(status: item.status)

            // Bottom row: provider + time
            HStack {
                // Provider
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(item.providerName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status label
                HStack(spacing: 4) {
                    Image(systemName: item.status.iconName)
                        .font(.caption2)
                    Text(item.status.displayText)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(item.status.color)

                Spacer()

                // Time
                Text(relativeTime(from: item.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Progress Bar (4 Steps)

    private func bridgeProgressBar(status: BridgeHistoryStatus) -> some View {
        let steps = ["Source", "Bridging", "Destination", "Done"]
        let currentStep = status.stepIndex
        let isFailed = status == .failed

        return HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                VStack(spacing: 4) {
                    // Progress segment
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor(stepIndex: index, currentStep: currentStep, isFailed: isFailed))
                        .frame(height: 3)

                    // Step label
                    Text(steps[index])
                        .font(.system(size: 8))
                        .foregroundColor(
                            index <= currentStep && !isFailed
                                ? .primary.opacity(0.7)
                                : .secondary.opacity(0.4)
                        )
                }
            }
        }
    }

    private func progressColor(stepIndex: Int, currentStep: Int, isFailed: Bool) -> Color {
        if isFailed {
            return stepIndex == 0 ? .red : Color(.systemGray4)
        }
        if stepIndex < currentStep {
            return .green
        } else if stepIndex == currentStep {
            return .blue
        } else {
            return Color(.systemGray4)
        }
    }

    // MARK: - Chain Icon

    private func chainIcon(name: String, logo: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 28, height: 28)

            // Try to use the logo string as SF Symbol or fallback to initial
            Text(String(name.prefix(1)))
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.3))

            Text(L("No Bridge History"))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text(L("Your cross-chain bridge transactions will appear here."))
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func formatAmount(_ amount: String) -> String {
        if let val = Double(amount) {
            if val >= 1000 {
                return String(format: "%.2f", val)
            } else if val >= 1 {
                return String(format: "%.4f", val)
            } else if val > 0 {
                return String(format: "%.6f", val)
            }
        }
        return amount
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 7 { return "\(days)d ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Bridge History Detail Sheet

/// Detail view for a single bridge transaction, showing source/destination tx links and full status.
struct BridgeHistoryDetailSheet: View {
    let item: BridgeHistoryItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Status header
                    statusHeader

                    // Progress visualization
                    detailedProgressView

                    // Transaction details
                    detailsCard

                    // Transaction links
                    linksCard

                    // Timestamps
                    timestampsCard
                }
                .padding()
            }
            .navigationTitle(L("Bridge Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 12) {
            // Status icon
            Image(systemName: item.status.iconName)
                .font(.system(size: 44))
                .foregroundColor(item.status.color)

            Text(item.status.displayText)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(item.status.color)

            // Amount summary
            HStack(spacing: 4) {
                Text(formatDetailAmount(item.amount))
                    .fontWeight(.semibold)
                Text(item.fromToken.symbol)
                    .foregroundColor(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatDetailAmount(item.toAmount))
                    .fontWeight(.semibold)
                Text(item.toToken.symbol)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(item.status.color.opacity(0.06))
        .cornerRadius(16)
    }

    // MARK: - Detailed Progress View

    private var detailedProgressView: some View {
        let steps: [(String, String, Int)] = [
            ("Source Confirmed", "checkmark.circle", 1),
            ("Bridging", "arrow.left.arrow.right", 2),
            ("Destination Confirmed", "checkmark.circle.fill", 3),
            ("Completed", "checkmark.seal.fill", 4),
        ]
        let currentStep = item.status.stepIndex
        let isFailed = item.status == .failed

        return VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 12) {
                    // Step circle / icon
                    ZStack {
                        Circle()
                            .fill(stepCircleColor(stepNum: step.2, currentStep: currentStep, isFailed: isFailed))
                            .frame(width: 32, height: 32)

                        if isFailed && step.2 == 1 {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                        } else if step.2 <= currentStep {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(step.2)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Step label
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.0)
                            .font(.subheadline)
                            .fontWeight(step.2 == currentStep ? .semibold : .regular)
                            .foregroundColor(step.2 <= currentStep ? .primary : .secondary)

                        if step.2 == currentStep && !isFailed && !item.status.isTerminal {
                            Text(L("In progress..."))
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 8)

                // Connecting line between steps
                if index < steps.count - 1 {
                    HStack {
                        Rectangle()
                            .fill(step.2 < currentStep ? Color.green : Color(.systemGray4))
                            .frame(width: 2, height: 20)
                            .padding(.leading, 15)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func stepCircleColor(stepNum: Int, currentStep: Int, isFailed: Bool) -> Color {
        if isFailed {
            return stepNum == 1 ? .red : Color(.systemGray4)
        }
        if stepNum <= currentStep {
            return .green
        }
        return Color(.systemGray4)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "From Chain", value: item.fromChain.name)
            Divider()
            detailRow(label: "To Chain", value: item.toChain.name)
            Divider()
            detailRow(label: "From Token", value: "\(formatDetailAmount(item.amount)) \(item.fromToken.symbol)")
            Divider()
            detailRow(label: "To Token", value: "\(formatDetailAmount(item.toAmount)) \(item.toToken.symbol)")
            Divider()
            detailRow(label: "Provider", value: item.providerName)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Links Card

    private var linksCard: some View {
        VStack(spacing: 0) {
            // Source transaction link
            Button(action: { openSourceTx() }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Source Transaction"))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(truncateHash(item.txHash))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            if let destHash = item.destinationTxHash, !destHash.isEmpty {
                Divider()

                // Destination transaction link
                Button(action: { openDestinationTx() }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Destination Transaction"))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(truncateHash(destHash))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Timestamps Card

    private var timestampsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "Started", value: formatDate(item.createdAt))
            if let completedAt = item.completedAt {
                Divider()
                detailRow(label: "Completed", value: formatDate(completedAt))
                Divider()
                let duration = completedAt.timeIntervalSince(item.createdAt)
                detailRow(label: "Duration", value: formatDuration(duration))
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func openSourceTx() {
        let urlString = "\(item.fromChain.scanUrl)/tx/\(item.txHash)"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    private func openDestinationTx() {
        guard let destHash = item.destinationTxHash else { return }
        let urlString = "\(item.toChain.scanUrl)/tx/\(destHash)"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    private func truncateHash(_ hash: String) -> String {
        guard hash.count > 14 else { return hash }
        let prefix = hash.prefix(8)
        let suffix = hash.suffix(6)
        return "\(prefix)...\(suffix)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        if seconds < 60 { return "\(seconds) seconds" }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes < 60 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes) minutes"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }

    private func formatDetailAmount(_ amount: String) -> String {
        if let val = Double(amount) {
            if val >= 1000 {
                return String(format: "%.2f", val)
            } else if val >= 1 {
                return String(format: "%.4f", val)
            } else if val > 0 {
                return String(format: "%.6f", val)
            }
        }
        return amount
    }
}

// MARK: - Previews

#if DEBUG
struct BridgeHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        BridgeHistoryView()
    }
}
#endif
