import SwiftUI

/// Bridge View - Cross-chain bridge interface
/// Redesigned to match extension wallet's bridge UX:
/// - Chain icon selectors with swap button
/// - Token selection with balance display
/// - Quote comparison from aggregators with best quote badge
/// - Slippage settings
/// - Bridge history navigation
/// - Estimated time, fees, gas display
/// - Progressive execution steps
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

    // Sheet states
    @State private var showConfirmation = false
    @State private var showFromChainPicker = false
    @State private var showToChainPicker = false
    @State private var showHistory = false
    @State private var showSlippage = false
    @State private var slippage: Double = 0.01 // 1% default
    @State private var isAutoSlippage = true
    @State private var isSameBridgeToken: Bool?

    // String localization helper
    private func S(_ key: String) -> String { LocalizationManager.shared.t(key) }

    // Supported chains for bridge
    private var bridgeChains: [Chain] {
        chainManager.mainnetChains.filter { chain in
            let supported = ["eth", "bsc", "arb", "op", "matic", "avax", "base", "linea", "era",
                             "scrl", "mnt", "xdai", "mode", "zora", "blast", "ftm", "cro"]
            return supported.contains(chain.serverId)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerBar
                    chainSelectorRow
                    amountInputSection

                    if bridgeManager.isLoading {
                        loadingQuotesView
                    } else if !bridgeManager.quotes.isEmpty {
                        quotesSection
                    } else if fromChain != nil && toChain != nil && !amount.isEmpty {
                        noQuotesView
                    }

                    if let error = errorMessage {
                        errorBanner(error)
                    }

                    if bridgeManager.executionStep.isInProgress {
                        executionProgressView
                    }

                    bridgeButton

                    if !bridgeManager.activeBridges.isEmpty {
                        activeBridgesSection
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(L("Bridge"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: amount) { _ in debounceQuotes() }
        .onChange(of: fromChain) { _ in clearAndFetch() }
        .onChange(of: toChain) { _ in clearAndFetch() }
        .onChange(of: bridgeManager.selectedFromToken?.id) { _ in clearAndFetch() }
        .onChange(of: bridgeManager.selectedToToken?.id) { _ in clearAndFetch() }
        .onChange(of: slippage) { _ in debounceQuotes() }
        .onChange(of: isAutoSlippage) { isAuto in
            guard isAuto else { return }
            let recommended = autoBridgeSlippage()
            if abs(slippage - recommended) > 0.000_001 {
                slippage = recommended
            }
        }
        .onDisappear {
            quoteTask?.cancel()
            sameTokenTask?.cancel()
        }
        .sheet(isPresented: $showConfirmation) { bridgeConfirmationSheet }
        .sheet(isPresented: $showHistory) { BridgeHistoryView() }
        .sheet(isPresented: $showSlippage) {
            BridgeSlippageSettingsSheet(
                slippage: $slippage,
                isAutoSlippage: $isAutoSlippage,
                autoSuggestedSlippage: autoBridgeSlippage()
            )
            .modifier(MediumDetentModifier())
        }
        .sheet(isPresented: $showFromChainPicker) {
            chainPickerSheet(title: S("From Chain"), excluding: toChain) { chain in
                fromChain = chain
                showFromChainPicker = false
            }
        }
        .sheet(isPresented: $showToChainPicker) {
            chainPickerSheet(title: S("To Chain"), excluding: fromChain) { chain in
                toChain = chain
                showToChainPicker = false
            }
        }
        .alert(L("Bridge Initiated"), isPresented: $showResult) {
            Button(L("OK")) {
                amount = ""
                selectedQuote = nil
                bridgeManager.resetExecutionState()
            }
        } message: {
            Text(L("Your bridge transaction has been sent. Track the cross-chain transfer in the active bridges section."))
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: { showSlippage = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape").font(.caption)
                    Text(isAutoSlippage ? "\(L("Auto")) \(formatSlippagePercent(slippage))" : formatSlippagePercent(slippage))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color(.systemGray6)).cornerRadius(8)
            }

            Spacer()

            Button(action: { showHistory = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath").font(.caption)
                    Text(L("History")).font(.caption)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.blue.opacity(0.1)).cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Chain Selectors

    private var chainSelectorRow: some View {
        HStack(spacing: 0) {
            chainCard(label: "From", chain: fromChain) { showFromChainPicker = true }

            Button(action: swapChains) {
                ZStack {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .offset(y: 10).zIndex(1)

            chainCard(label: "To", chain: toChain) { showToChainPicker = true }
        }
        .padding(.horizontal, 16)
    }

    private func chainCard(label: String, chain: Chain?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(label).font(.caption).foregroundColor(.secondary)

                if let chain = chain {
                    AsyncImage(url: URL(string: chain.logo)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Circle().fill(Color(.systemGray4))
                            .overlay(Text(String(chain.name.prefix(1))).font(.caption2).foregroundColor(.white))
                    }
                    .frame(width: 36, height: 36).clipShape(Circle())

                    Text(chain.name)
                        .font(.caption).fontWeight(.medium)
                        .foregroundColor(.primary).lineLimit(1)
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: "plus").font(.caption).foregroundColor(.secondary))
                    Text(L("Select")).font(.caption).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Color(.systemGray6)).cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount Input

    private var amountInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Amount")).font(.subheadline).foregroundColor(.secondary)
                Spacer()
                if fromChain != nil {
                    Button(action: { /* TODO: Set max balance */ }) {
                        Text("MAX").font(.caption).fontWeight(.semibold).foregroundColor(.blue)
                    }
                }
            }

            HStack {
                TextField("0.0", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .semibold))

                Spacer()

                if let chain = fromChain {
                    HStack(spacing: 6) {
                        AsyncImage(url: URL(string: chain.logo)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Circle().fill(Color(.systemGray4))
                        }
                        .frame(width: 24, height: 24).clipShape(Circle())

                        Text(chain.symbol).font(.subheadline).fontWeight(.medium)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(.systemGray5)).cornerRadius(20)
                }
            }
            .padding(16)
            .background(Color(.systemGray6)).cornerRadius(16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Loading Quotes

    private var loadingQuotesView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(L("Fetching best bridge routes..."))
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(20)
        .background(Color(.systemGray6)).cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Quotes Section

    private var quotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Bridge Routes")).font(.headline)
                Text("(\(bridgeManager.quotes.count))").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Button(action: fetchQuotes) {
                    Image(systemName: "arrow.clockwise").font(.caption).foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)

            ForEach(Array(bridgeManager.quotes.enumerated()), id: \.element.id) { index, quote in
                quoteCard(quote: quote, isBest: index == 0)
            }
        }
    }

    private func quoteCard(quote: BridgeManager.BridgeQuote, isBest: Bool) -> some View {
        Button(action: { selectedQuote = quote }) {
            HStack(spacing: 12) {
                // Aggregator icon
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(quote.aggregatorName.prefix(1)))
                            .font(.caption).fontWeight(.bold).foregroundColor(.blue)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(quote.aggregatorName)
                            .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)

                        if isBest {
                            Text(L("Best"))
                                .font(.caption2).fontWeight(.bold).foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green).cornerRadius(4)
                        }

                        if quote.needApprove {
                            Text(L("Approval"))
                                .font(.caption2).foregroundColor(.orange)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15)).cornerRadius(4)
                        }
                    }

                    HStack(spacing: 12) {
                        Label(quote.estimatedTime, systemImage: "clock")
                            .font(.caption2).foregroundColor(durationColor(quote.estimatedTime))
                        Label(quote.gasFee, systemImage: "fuelpump")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(quote.toAmount).font(.subheadline).fontWeight(.bold).foregroundColor(.primary)
                    if !quote.bridgeFee.isEmpty && quote.bridgeFee != "0" {
                        Text("Fee: \(quote.bridgeFee)").font(.caption2).foregroundColor(.secondary)
                    }
                }

                Image(systemName: selectedQuote?.id == quote.id ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedQuote?.id == quote.id ? .blue : .gray.opacity(0.3))
                    .font(.title3)
            }
            .padding(14)
            .background(selectedQuote?.id == quote.id ? Color.blue.opacity(0.08) : Color(.systemGray6))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedQuote?.id == quote.id ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func durationColor(_ time: String) -> Color {
        if time.contains("h") { return .red }
        if let mins = Int(time.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) {
            if mins > 10 { return .red }
            if mins > 3 { return .orange }
        }
        return .secondary
    }

    // MARK: - No Quotes

    private var noQuotesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.title2).foregroundColor(.secondary)
            Text(L("No bridge routes found")).font(.subheadline).foregroundColor(.secondary)
            Text(L("Try a different chain pair or amount")).font(.caption).foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(Color(.systemGray6)).cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(error).font(.caption).foregroundColor(.red)
            Spacer()
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.08)).cornerRadius(10)
        .padding(.horizontal, 16)
    }

    // MARK: - Bridge Button

    private var bridgeButton: some View {
        Button(action: { showConfirmation = true }) {
            HStack(spacing: 8) {
                if isBridging { ProgressView().tint(.white) }
                Text(bridgeButtonTitle).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(canBridge ? Color.blue : Color(.systemGray4))
            .foregroundColor(.white).cornerRadius(14)
        }
        .disabled(!canBridge || isBridging)
        .padding(.horizontal, 16)
    }

    private var canBridge: Bool {
        fromChain != nil && toChain != nil && !amount.isEmpty && selectedQuote != nil
    }

    private var bridgeButtonTitle: String {
        if isBridging { return bridgeManager.executionStep.displayText }
        if fromChain == nil || toChain == nil { return S("Select Chains") }
        if amount.isEmpty { return S("Enter Amount") }
        if selectedQuote == nil && !bridgeManager.quotes.isEmpty { return S("Select Route") }
        if selectedQuote == nil { return S("Enter Amount to Get Quotes") }
        return S("Bridge")
    }

    // MARK: - Execution Progress

    private var executionProgressView: some View {
        VStack(spacing: 12) {
            let steps: [(BridgeManager.BridgeExecutionStep, String)] = [
                (.checkingAllowance, S("Check Allowance")),
                (.approving, S("Approve Token")),
                (.waitingApprovalConfirmation, S("Confirm Approval")),
                (.buildingTransaction, S("Build Transaction")),
                (.signing, S("Sign Transaction")),
                (.sending, S("Send Transaction")),
                (.watchingBridgeStatus, S("Bridge in Progress")),
            ]

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 10) {
                        stepIcon(currentStep: bridgeManager.executionStep, index: index, steps: steps)
                        Text(step.1)
                            .font(.caption)
                            .foregroundColor(stepColor(currentStep: bridgeManager.executionStep, index: index, steps: steps))
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(Color(.systemGray6)).cornerRadius(14)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func stepIcon(currentStep: BridgeManager.BridgeExecutionStep, index: Int, steps: [(BridgeManager.BridgeExecutionStep, String)]) -> some View {
        let currentIndex = steps.firstIndex(where: { $0.0 == currentStep }) ?? -1
        if index < currentIndex {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
        } else if index == currentIndex {
            ProgressView().scaleEffect(0.7)
        } else {
            Image(systemName: "circle").foregroundColor(.gray.opacity(0.4)).font(.caption)
        }
    }

    private func stepColor(currentStep: BridgeManager.BridgeExecutionStep, index: Int, steps: [(BridgeManager.BridgeExecutionStep, String)]) -> Color {
        let currentIndex = steps.firstIndex(where: { $0.0 == currentStep }) ?? -1
        if index < currentIndex { return .green }
        if index == currentIndex { return .primary }
        return .secondary.opacity(0.4)
    }

    // MARK: - Active Bridges Section

    private var activeBridgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bolt.horizontal.circle.fill").foregroundColor(.blue)
                Text(L("Active Bridges")).font(.headline)
                Spacer()
                Text("\(bridgeManager.activeBridges.count)")
                    .font(.caption).fontWeight(.bold).foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.blue).cornerRadius(10)
            }
            .padding(.horizontal, 16)

            ForEach(Array(bridgeManager.activeBridges.values), id: \.fromTxHash) { state in
                activeBridgeRow(state: state)
            }
        }
    }

    private func activeBridgeRow(state: BridgeManager.BridgeWatchState) -> some View {
        HStack(spacing: 12) {
            Group {
                switch state.status {
                case .pending, .bridging:
                    ProgressView().scaleEffect(0.8)
                case .completed:
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                case .failed:
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(state.fromTokenSymbol) → \(state.toTokenSymbol)")
                    .font(.subheadline).fontWeight(.medium)
                Text(state.status.displayText).font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(state.fromAmount).font(.caption).fontWeight(.medium)
                Text(timeAgo(from: state.startedAt)).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemGray6)).cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - Confirmation Sheet

    private var bridgeConfirmationSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 0) {
                            confirmChainRow(label: "From", chain: fromChain, token: fromChain?.symbol ?? "", amount: amount)

                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2).foregroundColor(.blue).padding(.vertical, 4)

                            confirmChainRow(label: "To", chain: toChain, token: toChain?.symbol ?? "", amount: selectedQuote?.toAmount ?? "~")
                        }

                        if let quote = selectedQuote {
                            VStack(spacing: 0) {
                                confirmDetailRow(S("Bridge Provider"), quote.aggregatorName)
                                Divider()
                                confirmDetailRow(S("Estimated Time"), quote.estimatedTime)
                                Divider()
                                confirmDetailRow(S("Gas Fee"), quote.gasFee)
                                Divider()
                                confirmDetailRow(S("Bridge Fee"), quote.bridgeFee)
                                Divider()
                                confirmDetailRow(S("Slippage"), String(format: "%.1f%%", slippage * 100))

                                if quote.needApprove {
                                    Divider()
                                    confirmDetailRow(S("Token Approval"), S("Required"), color: .orange)
                                }
                                if quote.rabbyFee > 0 {
                                    Divider()
                                    confirmDetailRow(S("Rabby Fee"), String(format: "%.2f%%", quote.rabbyFee * 100))
                                }
                            }
                            .background(Color(.systemGray6)).cornerRadius(14)
                        }

                        if selectedQuote?.needApprove == true {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill").foregroundColor(.blue)
                                Text(L("This bridge requires a token approval transaction first. Two transactions will be sent."))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            .padding(12).background(Color.blue.opacity(0.08)).cornerRadius(10)
                        }
                    }
                    .padding(16)
                }

                VStack(spacing: 10) {
                    Button(action: { showConfirmation = false; executeBridge() }) {
                        Text(L("Confirm Bridge"))
                            .fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }

                    Button(action: { showConfirmation = false }) {
                        Text(L("Cancel"))
                            .fontWeight(.medium).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color(.systemGray5)).foregroundColor(.primary).cornerRadius(14)
                    }
                }
                .padding(16)
                .background(Color(.systemBackground).shadow(color: .black.opacity(0.05), radius: 8, y: -4))
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

    private func confirmChainRow(label: String, chain: Chain?, token: String, amount: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption).foregroundColor(.secondary)
                HStack(spacing: 6) {
                    if let chain = chain {
                        AsyncImage(url: URL(string: chain.logo)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Circle().fill(Color(.systemGray4))
                        }
                        .frame(width: 20, height: 20).clipShape(Circle())
                    }
                    Text(chain?.name ?? "").font(.subheadline).fontWeight(.medium)
                    Text(token).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(amount).font(.title2).fontWeight(.bold)
        }
        .padding(14).background(Color(.systemGray6)).cornerRadius(12)
    }

    private func confirmDetailRow(_ label: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.medium).foregroundColor(color)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Chain Picker Sheet

    private func chainPickerSheet(title: String, excluding: Chain?, action: @escaping (Chain) -> Void) -> some View {
        NavigationView {
            List {
                ForEach(bridgeChains.filter { $0.id != excluding?.id }) { chain in
                    Button(action: { action(chain) }) {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: chain.logo)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Circle().fill(Color(.systemGray4))
                                    .overlay(Text(String(chain.name.prefix(1))).font(.caption2).foregroundColor(.white))
                            }
                            .frame(width: 32, height: 32).clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(chain.name).font(.subheadline).fontWeight(.medium)
                                Text(chain.symbol).font(.caption).foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Cancel")) {
                        showFromChainPicker = false
                        showToChainPicker = false
                    }
                }
            }
        }
        .modifier(MediumLargeDetentModifier())
    }

    // MARK: - Actions

    private func swapChains() {
        let tmp = fromChain; fromChain = toChain; toChain = tmp
    }

    private func clearAndFetch() {
        refreshSameBridgeToken()
        selectedQuote = nil
        errorMessage = nil
        if isAutoSlippage {
            let suggested = autoBridgeSlippage()
            if abs(slippage - suggested) > 0.000_001 {
                slippage = suggested
                return
            }
        }
        if fromChain == nil || toChain == nil {
            bridgeManager.quotes = []
            return
        }
        fetchQuotes()
    }

    @State private var quoteTask: Task<Void, Never>?
    @State private var sameTokenTask: Task<Void, Never>?

    private func debounceQuotes() {
        quoteTask?.cancel()
        quoteTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !Task.isCancelled { fetchQuotes() }
        }
    }

    private func fetchQuotes() {
        guard let fc = fromChain, let tc = toChain, !amount.isEmpty,
              let address = PreferenceManager.shared.currentAccount?.address else {
            selectedQuote = nil
            bridgeManager.quotes = []
            return
        }
        errorMessage = nil
        let fromToken = bridgeToken(for: fc, selectedToken: bridgeManager.selectedFromToken)
        let toToken = bridgeToken(for: tc, selectedToken: bridgeManager.selectedToToken)
        Task {
            do {
                let q = try await bridgeManager.getQuotes(
                    fromToken: fromToken,
                    toToken: toToken,
                    amount: amount,
                    fromChain: fc,
                    toChain: tc,
                    userAddress: address,
                    slippage: slippage
                )
                selectedQuote = q.first
                if q.isEmpty {
                    errorMessage = "No bridge routes found"
                }
            } catch {
                selectedQuote = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshSameBridgeToken() {
        sameTokenTask?.cancel()
        guard let fromChain, let toChain else {
            isSameBridgeToken = nil
            return
        }

        let fromToken = bridgeToken(for: fromChain, selectedToken: bridgeManager.selectedFromToken)
        let toToken = bridgeToken(for: toChain, selectedToken: bridgeManager.selectedToToken)

        sameTokenTask = Task {
            let same = await bridgeManager.isSameBridgeToken(
                fromChainId: fromChain.serverId,
                fromTokenId: fromToken.id,
                toChainId: toChain.serverId,
                toTokenId: toToken.id
            )
            if Task.isCancelled { return }
            isSameBridgeToken = same
            if isAutoSlippage {
                let suggested = autoBridgeSlippage()
                if abs(slippage - suggested) > 0.000_001 {
                    slippage = suggested
                }
            }
        }
    }

    private func executeBridge() {
        guard let quote = selectedQuote, let fc = fromChain,
              let address = PreferenceManager.shared.currentAccount?.address else { return }

        isBridging = true; errorMessage = nil

        Task {
            do {
                let hash = try await bridgeManager.executeBridge(
                    quote: quote,
                    fromAddress: address,
                    fromChain: fc,
                    slippage: slippage
                )
                if let tc = toChain {
                    BridgeHistoryManager.shared.addBridgeTransaction(
                        quote: quote,
                        txHash: hash,
                        fromChain: fc,
                        toChain: tc
                    )
                }
                txHash = hash; showResult = true
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
        return "\(minutes / 60)h ago"
    }

    private func bridgeToken(for chain: Chain, selectedToken: SwapManager.Token?) -> SwapManager.Token {
        if let selectedToken, selectedToken.chain == chain.serverId {
            return selectedToken
        }
        return SwapManager.Token(
            id: chain.nativeTokenAddress,
            chain: chain.serverId,
            symbol: chain.symbol,
            decimals: chain.decimals,
            address: chain.nativeTokenAddress,
            logo: nil,
            amount: nil,
            price: nil
        )
    }

    private func autoBridgeSlippage() -> Double {
        guard let fromChain, let toChain else {
            return 0.01
        }
        if let isSameBridgeToken {
            return isSameBridgeToken ? 0.005 : 0.01
        }
        // Match extension behavior: same token bridge => 0.5%, otherwise 1%.
        return fromChain.symbol == toChain.symbol ? 0.005 : 0.01
    }

    private func formatSlippagePercent(_ value: Double) -> String {
        let percent = value * 100
        if percent == percent.rounded() {
            return String(format: "%.0f%%", percent)
        }
        var text = String(format: "%.2f", percent)
        while text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text + "%"
    }
}

private struct BridgeSlippageSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var slippage: Double
    @Binding var isAutoSlippage: Bool
    let autoSuggestedSlippage: Double

    @State private var localSlippage: Double = 0.01
    @State private var localAutoSlippage = true
    @State private var customInput = ""
    @State private var isCustomMode = false
    @State private var selectedPreset: Double? = nil
    @FocusState private var isCustomFocused: Bool

    private let presets: [Double] = [0.005, 0.01] // 0.5%, 1%
    private let minWarning = 0.002 // 0.2%
    private let maxWarning = 0.03 // 3%
    private let maxSlippage = 0.10 // 10%

    private var shouldShowLowWarning: Bool {
        !localAutoSlippage && localSlippage > 0 && localSlippage < minWarning
    }

    private var shouldShowHighWarning: Bool {
        !localAutoSlippage && localSlippage > maxWarning
    }

    private var isSaveEnabled: Bool {
        if localAutoSlippage {
            return true
        }
        return localSlippage > 0 && localSlippage <= maxSlippage
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Slippage Tolerance"))
                                .font(.headline)
                            Text(L("Your transaction will revert if the price changes unfavorably by more than this percentage."))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        autoOption
                        presetRow
                        customInputRow

                        if shouldShowLowWarning {
                            warningRow(
                                icon: "exclamationmark.triangle.fill",
                                text: "Your transaction may fail",
                                color: .orange
                            )
                        } else if shouldShowHighWarning {
                            warningRow(
                                icon: "exclamationmark.shield.fill",
                                text: "Your transaction may be frontrun",
                                color: .red
                            )
                        }
                    }
                    .padding(20)
                }

                Button(action: save) {
                    Text(L("Save"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSaveEnabled ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!isSaveEnabled)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L("Slippage Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
        }
        .onAppear(perform: syncFromBinding)
    }

    private var autoOption: some View {
        Button(action: selectAuto) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(localAutoSlippage ? .white : .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Auto"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(localAutoSlippage ? .white : .primary)
                    Text(formatPercent(autoSuggestedSlippage))
                        .font(.caption)
                        .foregroundColor(localAutoSlippage ? .white.opacity(0.85) : .secondary)
                }
                Spacer()
                if localAutoSlippage {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(localAutoSlippage ? Color.blue : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(localAutoSlippage ? Color.clear : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var presetRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Preset"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                ForEach(presets, id: \.self) { preset in
                    Button(action: { selectPreset(preset) }) {
                        Text(formatPercent(preset))
                            .font(.body.weight(.medium))
                            .foregroundColor(isPresetSelected(preset) ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isPresetSelected(preset) ? Color.blue : Color(.systemBackground))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isPresetSelected(preset) ? Color.clear : Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var customInputRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Custom"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                TextField("0.5", text: $customInput)
                    .keyboardType(.decimalPad)
                    .focused($isCustomFocused)
                    .onChange(of: customInput) { value in
                        guard !value.isEmpty else {
                            isCustomMode = true
                            selectedPreset = nil
                            return
                        }
                        isCustomMode = true
                        selectedPreset = nil
                        localAutoSlippage = false
                        localSlippage = normalizedCustomInput(value)
                    }
                    .onChange(of: isCustomFocused) { focused in
                        if focused {
                            isCustomMode = true
                            selectedPreset = nil
                            localAutoSlippage = false
                        }
                    }
                Text("%")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCustomMode && !localAutoSlippage ? Color.blue : Color(.systemGray4), lineWidth: isCustomMode && !localAutoSlippage ? 2 : 1)
            )
        }
    }

    private func warningRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.subheadline)
                .foregroundColor(color)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }

    private func syncFromBinding() {
        localAutoSlippage = isAutoSlippage
        if isAutoSlippage {
            localSlippage = autoSuggestedSlippage
            selectedPreset = nil
            isCustomMode = false
            customInput = ""
            return
        }

        localSlippage = slippage
        if presets.contains(where: { abs($0 - slippage) < 0.000_001 }) {
            selectedPreset = presets.first(where: { abs($0 - slippage) < 0.000_001 })
            isCustomMode = false
            customInput = ""
        } else {
            selectedPreset = nil
            isCustomMode = true
            customInput = formatNumber(slippage * 100)
        }
    }

    private func selectAuto() {
        localAutoSlippage = true
        localSlippage = autoSuggestedSlippage
        selectedPreset = nil
        isCustomMode = false
        customInput = ""
        isCustomFocused = false
    }

    private func selectPreset(_ preset: Double) {
        localAutoSlippage = false
        localSlippage = preset
        selectedPreset = preset
        isCustomMode = false
        customInput = ""
        isCustomFocused = false
    }

    private func isPresetSelected(_ preset: Double) -> Bool {
        guard !localAutoSlippage, !isCustomMode, let selectedPreset else { return false }
        return abs(selectedPreset - preset) < 0.000_001
    }

    private func save() {
        isAutoSlippage = localAutoSlippage
        if localAutoSlippage {
            slippage = autoSuggestedSlippage
        } else {
            slippage = min(max(localSlippage, 0), maxSlippage)
        }
        dismiss()
    }

    private func normalizedCustomInput(_ raw: String) -> Double {
        let cleaned = raw.replacingOccurrences(of: ",", with: ".")
        guard let percent = Double(cleaned), percent > 0 else {
            return 0
        }
        let clampedPercent = min(percent, maxSlippage * 100)
        return clampedPercent / 100
    }

    private func formatPercent(_ decimal: Double) -> String {
        formatNumber(decimal * 100) + "%"
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }
}

// MARK: - Presentation Detent Modifiers (iOS 16+ availability wrappers)

private struct MediumDetentModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium])
        } else {
            content
        }
    }
}

private struct MediumLargeDetentModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium, .large])
        } else {
            content
        }
    }
}
