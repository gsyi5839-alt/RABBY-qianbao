import SwiftUI

/// DeFi Lending operations - Supply/Borrow/Repay/Withdraw
/// Corresponds to: src/ui/views/Approval/ lending sections
struct LendingDashboardView: View {
    @StateObject private var lendingManager = LendingManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var showSupplySheet = false
    @State private var showBorrowSheet = false

    // MARK: - Computed Properties

    /// Aggregate all supply tokens across all positions
    private var allSupplyTokens: [LendingManager.LendingPosition.SupplyBorrowToken] {
        lendingManager.positions.flatMap { $0.supplyTokens }
    }

    /// Aggregate all borrow tokens across all positions
    private var allBorrowTokens: [LendingManager.LendingPosition.SupplyBorrowToken] {
        lendingManager.positions.flatMap { $0.borrowTokens }
    }

    /// Total supplied value across all positions
    private var totalSupplied: Double {
        lendingManager.positions.reduce(0) { $0 + $1.totalSupplyValue }
    }

    /// Total borrowed value across all positions
    private var totalBorrowed: Double {
        lendingManager.positions.reduce(0) { $0 + $1.totalBorrowValue }
    }

    /// Average health factor across positions that have one
    private var averageHealthFactor: Double {
        let positionsWithHealth = lendingManager.positions.compactMap { $0.healthRate }
        guard !positionsWithHealth.isEmpty else { return 0 }
        return positionsWithHealth.reduce(0, +) / Double(positionsWithHealth.count)
    }

    /// Average net APY across positions that have one
    private var averageNetAPY: Double {
        let apys = lendingManager.positions.compactMap { $0.netAPY }
        guard !apys.isEmpty else { return 0 }
        return apys.reduce(0, +) / Double(apys.count)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary cards
                    summarySection

                    // Health factor
                    if averageHealthFactor > 0 {
                        healthFactorGauge
                    }

                    // Supply positions
                    tokensSection(title: "Supplied", tokens: allSupplyTokens, color: .green)

                    // Borrow positions
                    tokensSection(title: "Borrowed", tokens: allBorrowTokens, color: .orange)

                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle(L("Lending"))
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showSupplySheet) { SupplySheet() }
        .sheet(isPresented: $showBorrowSheet) { BorrowSheet() }
        .task {
            guard let address = keyringManager.currentAccount?.address else { return }
            await lendingManager.loadPositions(address: address)
        }
    }

    private var summarySection: some View {
        HStack(spacing: 12) {
            SummaryCard(title: "Total Supplied", value: "$\(String(format: "%.2f", totalSupplied))", color: .green)
            SummaryCard(title: "Total Borrowed", value: "$\(String(format: "%.2f", totalBorrowed))", color: .orange)
            SummaryCard(title: "Net APY", value: "\(String(format: "%.2f", averageNetAPY))%", color: .blue)
        }
    }

    private var healthFactorGauge: some View {
        VStack(spacing: 8) {
            HStack {
                Text(L("Health Factor")).font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f", averageHealthFactor))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(healthFactorColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(healthFactorColor)
                        .frame(width: min(geo.size.width, geo.size.width * CGFloat(min(averageHealthFactor / 3.0, 1.0))), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text(L("Liquidation risk")).font(.caption2).foregroundColor(.red)
                Spacer()
                Text(L("Safe")).font(.caption2).foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var healthFactorColor: Color {
        if averageHealthFactor > 2.0 { return .green }
        if averageHealthFactor > 1.5 { return .yellow }
        return .red
    }

    private func tokensSection(title: String, tokens: [LendingManager.LendingPosition.SupplyBorrowToken], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)

            if tokens.isEmpty {
                Text("No \(title.lowercased()) positions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(tokens) { token in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(token.symbol.prefix(1)))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(token.symbol).font(.subheadline).fontWeight(.medium)
                            Text(String(format: "%.4f", token.amount))
                                .font(.caption2).foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(String(format: "%.2f", token.value))")
                                .font(.subheadline)
                            if let apy = token.apy {
                                Text("\(String(format: "%.2f", apy))% APY")
                                    .font(.caption2)
                                    .foregroundColor(color)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { showSupplySheet = true }) {
                Label(L("Supply"), systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            Button(action: { showBorrowSheet = true }) {
                Label(L("Borrow"), systemImage: "arrow.up.circle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.subheadline).fontWeight(.bold).foregroundColor(color)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Supply Sheet

struct SupplySheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedToken = ""
    @State private var amount = ""
    @State private var useAsCollateral = true

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Token selector
                HStack {
                    Text(L("Token")).foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $selectedToken) {
                        Text(L("ETH")).tag("ETH")
                        Text(L("USDC")).tag("USDC")
                        Text(L("USDT")).tag("USDT")
                        Text(L("DAI")).tag("DAI")
                        Text(L("WBTC")).tag("WBTC")
                    }
                    .pickerStyle(.menu)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Amount input
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Amount")).foregroundColor(.secondary)
                    HStack {
                        TextField(L("0.00"), text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                        Button(L("MAX")) { }
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // APY display
                HStack {
                    Text(L("Current APY")).foregroundColor(.secondary)
                    Spacer()
                    Text(L("3.25%")).foregroundColor(.green)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Collateral toggle
                Toggle(L("Use as collateral"), isOn: $useAsCollateral)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Supply \(selectedToken)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle(L("Supply"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Borrow Sheet

struct BorrowSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedToken = ""
    @State private var amount = ""
    @State private var isVariableRate = true

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                HStack {
                    Text(L("Token")).foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $selectedToken) {
                        Text(L("USDC")).tag("USDC")
                        Text(L("USDT")).tag("USDT")
                        Text(L("DAI")).tag("DAI")
                        Text(L("ETH")).tag("ETH")
                    }
                    .pickerStyle(.menu)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L("Amount")).foregroundColor(.secondary)
                        Spacer()
                        Text(L("Borrow limit: $10,000"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        TextField(L("0.00"), text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Rate type
                Picker(L("Rate"), selection: $isVariableRate) {
                    Text(L("Variable")).tag(true)
                    Text(L("Stable")).tag(false)
                }
                .pickerStyle(.segmented)

                HStack {
                    Text(L("Borrow APY")).foregroundColor(.secondary)
                    Spacer()
                    Text(isVariableRate ? "5.12%" : "7.80%").foregroundColor(.orange)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Health factor impact
                HStack {
                    Text(L("Health Factor Impact")).foregroundColor(.secondary)
                    Spacer()
                    Text(L("2.45 -> 1.82"))
                        .foregroundColor(.yellow)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Borrow \(selectedToken)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle(L("Borrow"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Repay Sheet

struct RepaySheet: View {
    @Environment(\.dismiss) var dismiss
    let token: LendingManager.LendingPosition.SupplyBorrowToken

    @State private var amount = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                HStack {
                    Text(L("Outstanding Debt")).foregroundColor(.secondary)
                    Spacer()
                    Text("$\(String(format: "%.2f", token.value))")
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Repay Amount")).foregroundColor(.secondary)
                    HStack {
                        TextField(L("0.00"), text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                        Button(L("MAX")) { amount = String(format: "%.6f", token.amount) }
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(token.symbol).foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()

                Button(action: { dismiss() }) {
                    Text(L("Repay"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Repay \(token.symbol)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
