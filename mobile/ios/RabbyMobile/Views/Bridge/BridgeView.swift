import SwiftUI

/// Bridge View - Cross-chain bridge interface with full execution pipeline
struct BridgeView: View {
    @StateObject private var bridgeManager = BridgeManager.shared
    @StateObject private var chainManager = ChainManager.shared
    @State private var fromChain: Chain?
    @State private var toChain: Chain?
    @State private var amount = ""
    @State private var selectedQuote: BridgeManager.BridgeQuote?
    @State private var isBridging = false
    @State private var showResult = false
    @State private var txHash: String?
    @State private var errorMessage: String?

    // Confirmation popup state
    @State private var showConfirmation = false

    // Active bridge status tracking
    @State private var showBridgeTracker = false
    @State private var activeTxHash: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Chain selector
                    HStack(spacing: 12) {
                        chainSelector(title: "From", chain: fromChain) { fromChain = $0 }
                        Button(action: swapChains) {
                            Image(systemName: "arrow.left.arrow.right").foregroundColor(.blue)
                        }
                        chainSelector(title: "To", chain: toChain) { toChain = $0 }
                    }.padding(.horizontal)

                    // Amount input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Amount")).font(.caption).foregroundColor(.secondary)
                        TextField(L("0.0"), text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }.padding(.horizontal)

                    // Quotes section
                    if bridgeManager.isLoading {
                        HStack {
                            ProgressView()
                            Text(L("Fetching bridge routes...")).font(.caption).foregroundColor(.secondary)
                        }.padding()
                    } else if !bridgeManager.quotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Bridge Routes")).font(.headline).padding(.horizontal)
                            ForEach(bridgeManager.quotes) { quote in
                                bridgeQuoteRow(quote: quote)
                            }
                        }
                    }

                    // Error message
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }

                    // Execution progress indicator
                    if bridgeManager.executionStep.isInProgress {
                        executionProgressView
                    }

                    // Bridge button
                    Button(action: { showConfirmation = true }) {
                        HStack {
                            if isBridging { ProgressView().tint(.white) }
                            Text(bridgeButtonTitle)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(canBridge ? Color.blue : Color.gray)
                        .foregroundColor(.white).cornerRadius(12)
                    }
                    .disabled(!canBridge || isBridging)
                    .padding(.horizontal)

                    // Active bridge tracker section
                    if !bridgeManager.activeBridges.isEmpty {
                        activeBridgesSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(L("Bridge"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: amount) { _ in fetchQuotes() }
        .onChange(of: fromChain) { _ in fetchQuotes() }
        .onChange(of: toChain) { _ in fetchQuotes() }
        // Confirmation sheet
        .sheet(isPresented: $showConfirmation) {
            bridgeConfirmationSheet
        }
        // Success alert
        .alert(L("Bridge Initiated"), isPresented: $showResult) {
            Button(L("OK")) {
                amount = ""
                selectedQuote = nil
                bridgeManager.resetExecutionState()
            }
        } message: {
            Text("Your bridge transaction has been sent. Track the cross-chain transfer in the bridge status section below.\n\nTx: \(txHash ?? "")")
        }
    }

    // MARK: - Computed Properties

    private var canBridge: Bool {
        fromChain != nil && toChain != nil && !amount.isEmpty && selectedQuote != nil
    }

    private var bridgeButtonTitle: String {
        if isBridging {
            return bridgeManager.executionStep.displayText
        }
        if fromChain == nil || toChain == nil {
            return LocalizationManager.shared.t("Select Chains")
        }
        if amount.isEmpty {
            return LocalizationManager.shared.t("Enter Amount")
        }
        if selectedQuote == nil {
            return LocalizationManager.shared.t("Select Route")
        }
        return LocalizationManager.shared.t("Bridge")
    }

    // MARK: - Execution Progress View

    private var executionProgressView: some View {
        VStack(spacing: 12) {
            // Progress steps
            let steps: [(BridgeManager.BridgeExecutionStep, String)] = [
                (.checkingAllowance, LocalizationManager.shared.t("Check Allowance")),
                (.approving, LocalizationManager.shared.t("Approve Token")),
                (.waitingApprovalConfirmation, LocalizationManager.shared.t("Confirm Approval")),
                (.buildingTransaction, LocalizationManager.shared.t("Build Transaction")),
                (.signing, LocalizationManager.shared.t("Sign Transaction")),
                (.sending, LocalizationManager.shared.t("Send Transaction")),
                (.watchingBridgeStatus, LocalizationManager.shared.t("Bridge in Progress")),
            ]

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 10) {
                        stepStatusIcon(currentStep: bridgeManager.executionStep, targetStep: step.0, index: index, steps: steps)
                        Text(step.1)
                            .font(.caption)
                            .foregroundColor(stepTextColor(currentStep: bridgeManager.executionStep, targetStep: step.0, index: index, steps: steps))
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func stepStatusIcon(currentStep: BridgeManager.BridgeExecutionStep, targetStep: BridgeManager.BridgeExecutionStep, index: Int, steps: [(BridgeManager.BridgeExecutionStep, String)]) -> some View {
        let currentIndex = steps.firstIndex(where: { $0.0 == currentStep }) ?? -1

        if index < currentIndex {
            // Completed
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        } else if index == currentIndex {
            // Current
            ProgressView()
                .scaleEffect(0.7)
        } else {
            // Pending
            Image(systemName: "circle")
                .foregroundColor(.gray.opacity(0.5))
                .font(.caption)
        }
    }

    private func stepTextColor(currentStep: BridgeManager.BridgeExecutionStep, targetStep: BridgeManager.BridgeExecutionStep, index: Int, steps: [(BridgeManager.BridgeExecutionStep, String)]) -> Color {
        let currentIndex = steps.firstIndex(where: { $0.0 == currentStep }) ?? -1

        if index < currentIndex {
            return .green
        } else if index == currentIndex {
            return .primary
        } else {
            return .secondary.opacity(0.5)
        }
    }

    // MARK: - Confirmation Sheet

    private var bridgeConfirmationSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // From section
                        VStack(spacing: 8) {
                            Text(L("From")).font(.caption).foregroundColor(.secondary)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(fromChain?.name ?? "").fontWeight(.medium)
                                    Text(selectedQuote?.fromToken.symbol ?? fromChain?.symbol ?? "")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(amount)
                                    .font(.title2).fontWeight(.bold)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Arrow
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)

                        // To section
                        VStack(spacing: 8) {
                            Text(L("To")).font(.caption).foregroundColor(.secondary)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(toChain?.name ?? "").fontWeight(.medium)
                                    Text(selectedQuote?.toToken.symbol ?? toChain?.symbol ?? "")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(selectedQuote?.toAmount ?? "~")
                                    .font(.title2).fontWeight(.bold)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Details section
                        if let quote = selectedQuote {
                            VStack(spacing: 0) {
                                confirmationDetailRow(label: "Bridge", value: quote.aggregatorName)
                                Divider()
                                confirmationDetailRow(label: LocalizationManager.shared.t("Estimated Time"), value: quote.estimatedTime)
                                Divider()
                                confirmationDetailRow(label: LocalizationManager.shared.t("Gas Fee"), value: quote.gasFee)
                                Divider()
                                confirmationDetailRow(label: LocalizationManager.shared.t("Bridge Fee"), value: quote.bridgeFee)

                                if quote.needApprove {
                                    Divider()
                                    confirmationDetailRow(label: LocalizationManager.shared.t("Approval"), value: LocalizationManager.shared.t("Required"), valueColor: .orange)
                                }

                                if quote.rabbyFee > 0 {
                                    Divider()
                                    confirmationDetailRow(label: LocalizationManager.shared.t("Rabby Fee"), value: String(format: "%.2f%%", quote.rabbyFee * 100))
                                }
                            }
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Warning for approval
                        if selectedQuote?.needApprove == true {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill").foregroundColor(.blue)
                                Text(L("This bridge requires a token approval transaction before the bridge transaction. Two transactions will be sent."))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }

                // Bottom buttons
                VStack(spacing: 12) {
                    Button(action: {
                        showConfirmation = false
                        executeBridge()
                    }) {
                        Text(L("Confirm Bridge"))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: { showConfirmation = false }) {
                        Text(L("Cancel"))
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemBackground).shadow(radius: 2))
            }
            .navigationTitle(L("Confirm Bridge"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showConfirmation = false }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func confirmationDetailRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.medium).foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Active Bridges Section

    private var activeBridgesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Active Bridges")).font(.headline).padding(.horizontal)

            ForEach(Array(bridgeManager.activeBridges.values), id: \.fromTxHash) { bridgeState in
                activeBridgeRow(state: bridgeState)
            }
        }
    }

    private func activeBridgeRow(state: BridgeManager.BridgeWatchState) -> some View {
        HStack {
            // Status icon
            Group {
                switch state.status {
                case .pending:
                    ProgressView().scaleEffect(0.8)
                case .bridging:
                    ProgressView().scaleEffect(0.8)
                case .completed:
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                case .failed:
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                }
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(state.fromTokenSymbol) -> \(state.toTokenSymbol)")
                    .font(.subheadline).fontWeight(.medium)
                Text(state.status.displayText)
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(state.fromAmount).font(.caption).foregroundColor(.secondary)
                Text(timeAgo(from: state.startedAt))
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // MARK: - Subviews

    private func chainSelector(title: String, chain: Chain?, action: @escaping (Chain) -> Void) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Menu {
                ForEach(chainManager.mainnetChains) { c in
                    Button(c.name) { action(c) }
                }
            } label: {
                VStack {
                    Text(chain?.symbol ?? "?").font(.title2).fontWeight(.bold)
                    Text(chain?.name ?? LocalizationManager.shared.t("Select")).font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color(.systemGray6)).cornerRadius(12)
            }
        }
    }

    private func bridgeQuoteRow(quote: BridgeManager.BridgeQuote) -> some View {
        Button(action: { selectedQuote = quote }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.aggregatorName).fontWeight(.medium)
                    HStack(spacing: 4) {
                        Text("~\(quote.estimatedTime)").font(.caption).foregroundColor(.secondary)
                        if quote.needApprove {
                            Text(L("Approval needed"))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(quote.toAmount).fontWeight(.semibold)
                    Text("Fee: \(quote.bridgeFee)").font(.caption).foregroundColor(.secondary)
                }
                if selectedQuote?.id == quote.id {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                }
            }
            .padding()
            .background(selectedQuote?.id == quote.id ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain).padding(.horizontal)
    }

    // MARK: - Actions

    private func swapChains() { let t = fromChain; fromChain = toChain; toChain = t }

    private func fetchQuotes() {
        guard let fc = fromChain, let tc = toChain, !amount.isEmpty,
              let address = PreferenceManager.shared.currentAccount?.address else { return }
        Task {
            do {
                let q = try await bridgeManager.getQuotes(
                    fromToken: SwapManager.Token(id: fc.nativeTokenAddress, chain: fc.serverId, symbol: fc.symbol, decimals: fc.decimals, address: fc.nativeTokenAddress, logo: nil, amount: nil, price: nil),
                    toToken: SwapManager.Token(id: tc.nativeTokenAddress, chain: tc.serverId, symbol: tc.symbol, decimals: tc.decimals, address: tc.nativeTokenAddress, logo: nil, amount: nil, price: nil),
                    amount: amount, fromChain: fc, toChain: tc, userAddress: address
                )
                selectedQuote = q.first
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func executeBridge() {
        guard let quote = selectedQuote, let fc = fromChain,
              let address = PreferenceManager.shared.currentAccount?.address else { return }

        isBridging = true
        errorMessage = nil

        Task {
            do {
                let hash = try await bridgeManager.executeBridge(
                    quote: quote,
                    fromAddress: address,
                    fromChain: fc
                )
                txHash = hash
                showResult = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isBridging = false
        }
    }

    // MARK: - Helpers

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }
}
