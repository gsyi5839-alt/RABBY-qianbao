import SwiftUI

// MARK: - Sort Mode

enum AggregatorSortMode: String, CaseIterable, Identifiable {
    case bestRate = "Best Rate"
    case fastest = "Fastest"
    case lowestFee = "Lowest Fee"

    var id: String { rawValue }
}

// MARK: - BridgeAggregatorSheet

/// Sheet that displays available bridge aggregators/providers for cross-chain bridging.
/// Users can sort by best rate, fastest, or lowest fee, and toggle specific providers on/off.
struct BridgeAggregatorSheet: View {
    @ObservedObject var bridgeManager: BridgeManager
    @Binding var selectedQuote: BridgeManager.BridgeQuote?
    @Environment(\.dismiss) private var dismiss

    @State private var sortMode: AggregatorSortMode = .bestRate
    @State private var disabledProviderIds: Set<String> = []

    /// Known aggregator metadata for icon/display fallback
    private static let knownAggregators: [String: (icon: String, color: Color)] = [
        "socket": (icon: "bolt.fill", color: .purple),
        "lifi": (icon: "arrow.triangle.swap", color: .blue),
        "debridge": (icon: "link", color: .orange),
        "stargate": (icon: "star.fill", color: .yellow),
        "across": (icon: "arrow.left.arrow.right.circle.fill", color: .green),
        "cbridge": (icon: "c.circle.fill", color: .cyan),
        "hop": (icon: "hare.fill", color: .pink),
        "multichain": (icon: "circle.grid.cross.fill", color: .indigo),
        "synapse": (icon: "brain.head.profile", color: .mint),
        "allbridge": (icon: "globe", color: .teal),
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sort mode picker
                sortPicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider()

                // Provider filter toggles
                if !allAggregatorIds.isEmpty {
                    filterSection
                    Divider()
                }

                // Quote list
                if sortedQuotes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(sortedQuotes.enumerated()), id: \.element.id) { index, quote in
                                quoteRow(quote: quote, index: index)

                                if index < sortedQuotes.count - 1 {
                                    Divider().padding(.leading, 60)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(L("Select Provider"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Sort by"))
                .font(.caption)
                .foregroundColor(.secondary)

            Picker(L("Sort"), selection: $sortMode) {
                ForEach(AggregatorSortMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allAggregatorIds, id: \.self) { aggId in
                    let name = aggregatorDisplayName(for: aggId)
                    let isEnabled = !disabledProviderIds.contains(aggId)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isEnabled {
                                disabledProviderIds.insert(aggId)
                            } else {
                                disabledProviderIds.remove(aggId)
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            aggregatorIcon(for: aggId, size: 14)
                            Text(name)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isEnabled ? Color.blue.opacity(0.12) : Color(.systemGray5))
                        .foregroundColor(isEnabled ? .blue : .secondary)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isEnabled ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Quote Row

    private func quoteRow(quote: BridgeManager.BridgeQuote, index: Int) -> some View {
        Button(action: {
            selectedQuote = quote
            dismiss()
        }) {
            HStack(spacing: 12) {
                // Provider icon
                aggregatorIcon(for: quote.aggregatorId, size: 36)

                // Provider info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(quote.aggregatorName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        // Badge on top option depending on sort mode
                        if index == 0 {
                            sortBadge
                        }
                    }

                    HStack(spacing: 12) {
                        // Estimated time
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(quote.estimatedTime)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)

                        // Fee
                        HStack(spacing: 3) {
                            Image(systemName: "dollarsign.circle")
                                .font(.caption2)
                            Text("Fee: \(quote.bridgeFee)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Output amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatOutputAmount(quote.toAmount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(quote.toToken.symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Selection checkmark
                if selectedQuote?.id == quote.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary.opacity(0.3))
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                selectedQuote?.id == quote.id
                    ? Color.blue.opacity(0.06)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Badge view for the top-ranked provider based on current sort mode
    @ViewBuilder
    private var sortBadge: some View {
        switch sortMode {
        case .bestRate:
            badgeLabel(LocalizationManager.shared.t("Best Rate"), color: .green)
        case .fastest:
            badgeLabel(LocalizationManager.shared.t("Fastest"), color: .orange)
        case .lowestFee:
            badgeLabel(LocalizationManager.shared.t("Lowest Fee"), color: .blue)
        }
    }

    private func badgeLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))
            Text(L("No Bridge Routes Available"))
                .font(.headline)
                .foregroundColor(.secondary)
            Text(L("Try adjusting your filters or changing the token pair."))
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if !disabledProviderIds.isEmpty {
                Button(L("Clear Filters")) {
                    disabledProviderIds.removeAll()
                }
                .font(.subheadline.weight(.medium))
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    /// All unique aggregator IDs from current quotes
    private var allAggregatorIds: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for quote in bridgeManager.quotes {
            if !seen.contains(quote.aggregatorId) {
                seen.insert(quote.aggregatorId)
                result.append(quote.aggregatorId)
            }
        }
        return result
    }

    /// Filtered and sorted quotes
    private var sortedQuotes: [BridgeManager.BridgeQuote] {
        let filtered = bridgeManager.quotes.filter { !disabledProviderIds.contains($0.aggregatorId) }

        switch sortMode {
        case .bestRate:
            return filtered.sorted { lhs, rhs in
                (Double(lhs.toAmount) ?? 0) > (Double(rhs.toAmount) ?? 0)
            }
        case .fastest:
            return filtered.sorted { lhs, rhs in
                parseEstimatedSeconds(lhs.estimatedTime) < parseEstimatedSeconds(rhs.estimatedTime)
            }
        case .lowestFee:
            return filtered.sorted { lhs, rhs in
                parseFeeValue(lhs.bridgeFee) < parseFeeValue(rhs.bridgeFee)
            }
        }
    }

    /// Parse estimated time string into rough seconds for sorting
    private func parseEstimatedSeconds(_ time: String) -> Int {
        let lower = time.lowercased()
        let digits = lower.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let value = Int(digits) ?? 999

        if lower.contains("sec") { return value }
        if lower.contains("min") { return value * 60 }
        if lower.contains("hour") || lower.contains("hr") { return value * 3600 }
        return value * 60 // default assume minutes
    }

    /// Parse fee string into a numeric value for sorting
    private func parseFeeValue(_ fee: String) -> Double {
        let cleaned = fee.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 999999
    }

    /// Format a potentially long output amount string
    private func formatOutputAmount(_ amount: String) -> String {
        if let val = Double(amount) {
            if val >= 1000 {
                return String(format: "%.2f", val)
            } else if val >= 1 {
                return String(format: "%.4f", val)
            } else {
                return String(format: "%.6f", val)
            }
        }
        return amount
    }

    /// Get display name for aggregator
    private func aggregatorDisplayName(for aggId: String) -> String {
        if let quote = bridgeManager.quotes.first(where: { $0.aggregatorId == aggId }) {
            return quote.aggregatorName
        }
        return aggId.capitalized
    }

    /// Build an aggregator icon view
    @ViewBuilder
    private func aggregatorIcon(for aggId: String, size: CGFloat) -> some View {
        let lowerId = aggId.lowercased()
        let meta = Self.knownAggregators[lowerId]

        if let quote = bridgeManager.quotes.first(where: { $0.aggregatorId == aggId }),
           let logoUrl = quote.aggregatorLogo,
           let url = URL(string: logoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
                default:
                    fallbackIcon(systemName: meta?.icon ?? "arrow.triangle.swap",
                                 color: meta?.color ?? .gray,
                                 size: size)
                }
            }
        } else {
            fallbackIcon(systemName: meta?.icon ?? "arrow.triangle.swap",
                         color: meta?.color ?? .gray,
                         size: size)
        }
    }

    private func fallbackIcon(systemName: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.5))
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BridgeAggregatorSheet_Previews: PreviewProvider {
    static var previews: some View {
        BridgeAggregatorSheet(
            bridgeManager: BridgeManager.shared,
            selectedQuote: .constant(nil)
        )
    }
}
#endif
