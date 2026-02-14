import SwiftUI

/// Perpetual futures trading popup system
/// Open/Close/AddMargin/Risk warnings
struct PerpsPopups {
    // Namespace for perps popup views
}

// MARK: - Open Position Sheet

struct OpenPositionSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var perpsManager = PerpsManager.shared

    @State private var selectedMarket = "ETH-PERP"
    @State private var isLong = true
    @State private var leverage: Double = 5
    @State private var marginAmount = ""
    @State private var orderType: OrderType = .market
    @State private var limitPrice = ""
    @State private var takeProfit = ""
    @State private var stopLoss = ""
    @State private var showRiskWarning = false

    enum OrderType: String, CaseIterable {
        case market = "Market"
        case limit = "Limit"
    }

    let leveragePresets: [Double] = [1, 2, 5, 10, 25, 50, 100]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Market selector
                    marketSelector

                    // Long/Short toggle
                    longShortToggle

                    // Leverage
                    leverageSection

                    // Order type
                    orderTypeSection

                    // Margin input
                    marginInputSection

                    // TP/SL
                    tpSlSection

                    // Preview
                    positionPreview

                    // Confirm
                    confirmButton
                }
                .padding()
            }
            .navigationTitle(L("Open Position"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) { dismiss() }
                }
            }
        }
        .alert(L("High Leverage Warning"), isPresented: $showRiskWarning) {
            Button(L("I Understand the Risk"), role: .destructive) { executeOrder() }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("Leverage above 20x significantly increases liquidation risk. You could lose your entire margin."))
        }
    }

    private var marketSelector: some View {
        HStack {
            Text(L("Market"))
                .foregroundColor(.secondary)
            Spacer()
            Picker("", selection: $selectedMarket) {
                Text(L("BTC-PERP")).tag("BTC-PERP")
                Text(L("ETH-PERP")).tag("ETH-PERP")
                Text(L("SOL-PERP")).tag("SOL-PERP")
                Text(L("ARB-PERP")).tag("ARB-PERP")
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var longShortToggle: some View {
        HStack(spacing: 0) {
            Button(action: { isLong = true }) {
                Text(L("Long"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isLong ? Color.green : Color(.systemGray5))
                    .foregroundColor(isLong ? .white : .primary)
            }
            Button(action: { isLong = false }) {
                Text(L("Short"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(!isLong ? Color.red : Color(.systemGray5))
                    .foregroundColor(!isLong ? .white : .primary)
            }
        }
        .cornerRadius(12)
    }

    private var leverageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Leverage")).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(leverage))x")
                    .fontWeight(.semibold)
                    .foregroundColor(leverage > 20 ? .red : .primary)
            }

            Slider(value: $leverage, in: 1...100, step: 1)
                .tint(leverage > 20 ? .red : .blue)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(leveragePresets, id: \.self) { preset in
                        Button("\(Int(preset))x") { leverage = preset }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(leverage == preset ? Color.blue : Color(.systemGray5))
                            .foregroundColor(leverage == preset ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var orderTypeSection: some View {
        VStack(spacing: 8) {
            Picker(L("Order Type"), selection: $orderType) {
                ForEach(OrderType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if orderType == .limit {
                HStack {
                    Text(L("Limit Price")).foregroundColor(.secondary)
                    TextField(L("0.00"), text: $limitPrice)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(L("USD")).foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }

    private var marginInputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L("Margin")).foregroundColor(.secondary)
                Spacer()
                Text(L("Balance: --"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                TextField(L("0.00"), text: $marginAmount)
                    .keyboardType(.decimalPad)
                    .font(.title3)
                Button(L("MAX")) { /* fill max balance */ }
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(L("USDC")).foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private var tpSlSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(L("Take Profit")).font(.caption).foregroundColor(.secondary)
                TextField(L("Optional"), text: $takeProfit)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.caption)
            }
            HStack {
                Text(L("Stop Loss")).font(.caption).foregroundColor(.secondary)
                TextField(L("Optional"), text: $stopLoss)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var positionPreview: some View {
        VStack(spacing: 8) {
            HStack {
                Text(L("Position Size")).foregroundColor(.secondary)
                Spacer()
                let marginVal = Double(marginAmount) ?? 0
                Text("$\(String(format: "%.2f", marginVal * leverage))")
                    .fontWeight(.semibold)
            }
            HStack {
                Text(L("Est. Fee")).foregroundColor(.secondary)
                Spacer()
                let marginVal = Double(marginAmount) ?? 0
                Text("~$\(String(format: "%.2f", marginVal * leverage * 0.001))")
            }
        }
        .font(.subheadline)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var confirmButton: some View {
        Button(action: {
            if leverage > 20 { showRiskWarning = true }
            else { executeOrder() }
        }) {
            Text(isLong ? "Open Long" : "Open Short")
                .frame(maxWidth: .infinity)
                .padding()
                .background(isLong ? Color.green : Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.body.weight(.semibold))
        }
    }

    private func executeOrder() {
        dismiss()
    }
}

// MARK: - Close Position Sheet

struct ClosePositionSheet: View {
    @Environment(\.dismiss) var dismiss

    let position: PerpsPosition
    @State private var closePercent: Double = 100
    @State private var isMarketClose = true
    @State private var limitClosePrice = ""

    let percentPresets: [Double] = [25, 50, 75, 100]

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Position summary
                VStack(spacing: 8) {
                    HStack {
                        Text(position.symbol).font(.headline)
                        Text(position.side == .long ? "LONG" : "SHORT")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(position.side == .long ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .cornerRadius(4)
                        Spacer()
                    }

                    HStack {
                        infoCol("Entry Price", "$\(String(format: "%.2f", position.entryPrice))")
                        infoCol("Size", "$\(String(format: "%.2f", position.size))")
                        infoCol("PnL", String(format: "$%.2f", position.unrealizedPnl))
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Close amount
                VStack(spacing: 8) {
                    Text("Close \(Int(closePercent))%")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Slider(value: $closePercent, in: 1...100, step: 1)

                    HStack(spacing: 8) {
                        ForEach(percentPresets, id: \.self) { p in
                            Button("\(Int(p))%") { closePercent = p }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(closePercent == p ? Color.blue : Color(.systemGray5))
                                .foregroundColor(closePercent == p ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }

                // Market/Limit toggle
                Picker("", selection: $isMarketClose) {
                    Text(L("Market")).tag(true)
                    Text(L("Limit")).tag(false)
                }
                .pickerStyle(.segmented)

                if !isMarketClose {
                    HStack {
                        Text(L("Close Price")).foregroundColor(.secondary)
                        TextField(L("0.00"), text: $limitClosePrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                // Estimated PnL
                let estPnl = position.unrealizedPnl * closePercent / 100
                HStack {
                    Text(L("Estimated PnL")).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "$%.2f", estPnl))
                        .foregroundColor(estPnl >= 0 ? .green : .red)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()

                Button(action: { dismiss() }) {
                    Text(L("Close Position"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle(L("Close Position"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func infoCol(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.caption).fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add Margin Sheet

struct AddMarginSheet: View {
    @Environment(\.dismiss) var dismiss

    let position: PerpsPosition
    @State private var addAmount = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    HStack {
                        Text(L("Current Margin")).foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", position.margin))")
                    }
                    HStack {
                        Text(L("Liquidation Price")).foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", position.liquidationPrice))")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Add Margin Amount")).foregroundColor(.secondary)
                    HStack {
                        TextField(L("0.00"), text: $addAmount)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                        Text(L("USDC")).foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Preview
                if let amount = Double(addAmount), amount > 0 {
                    let newMargin = position.margin + amount
                    let newLiqPrice = position.liquidationPrice * position.margin / newMargin
                    VStack(spacing: 8) {
                        HStack {
                            Text(L("New Margin")).foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.2f", newMargin))")
                        }
                        HStack {
                            Text(L("New Liq. Price")).foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.2f", newLiqPrice))")
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Text(L("Add Margin"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle(L("Add Margin"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

