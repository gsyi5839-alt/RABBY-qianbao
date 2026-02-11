import SwiftUI

/// Gas price bar showing current chain gas prices
/// Corresponds to: src/ui/views/Dashboard/components/GasPriceBar/
struct GasPriceBarView: View {
    @StateObject private var chainManager = ChainManager.shared
    @State private var gasPrice: OpenAPIService.GasPrice?
    @State private var isLoading = true
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Collapsed: single row with gas indicator
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "fuelpump.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    if isLoading {
                        ProgressView().scaleEffect(0.6)
                    } else if let gas = gasPrice {
                        Text("\(formatGwei(gas.normal.price)) Gwei")
                            .font(.caption).fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if let seconds = gas.normal.estimated_seconds {
                            Text("~\(formatTime(seconds))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Gas unavailable")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let chain = chainManager.selectedChain {
                        Text(chain.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded: show all gas levels
            if isExpanded, let gas = gasPrice {
                Divider()
                
                HStack(spacing: 0) {
                    gasLevelCard(title: "Slow", level: gas.slow, color: .green)
                    
                    Divider().frame(height: 44)
                    
                    gasLevelCard(title: "Normal", level: gas.normal, color: .orange)
                    
                    Divider().frame(height: 44)
                    
                    gasLevelCard(title: "Fast", level: gas.fast, color: .red)
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .task { await loadGasPrice() }
    }
    
    // MARK: - Gas Level Card
    
    private func gasLevelCard(title: String, level: OpenAPIService.GasLevel, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(formatGwei(level.price))
                .font(.caption).fontWeight(.bold)
                .foregroundColor(color)
            
            Text("Gwei")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
            
            if let seconds = level.estimated_seconds {
                Text("~\(formatTime(seconds))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helpers
    
    private func loadGasPrice() async {
        guard let chain = chainManager.selectedChain else { return }
        isLoading = true
        do {
            gasPrice = try await OpenAPIService.shared.getGasPrice(chainId: chain.serverId)
        } catch {
            gasPrice = nil
        }
        isLoading = false
    }
    
    private func formatGwei(_ price: Int) -> String {
        let gwei = Double(price) / 1_000_000_000
        if gwei >= 100 { return String(format: "%.0f", gwei) }
        if gwei >= 10 { return String(format: "%.1f", gwei) }
        return String(format: "%.2f", gwei)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h\(minutes % 60)m"
    }
}
