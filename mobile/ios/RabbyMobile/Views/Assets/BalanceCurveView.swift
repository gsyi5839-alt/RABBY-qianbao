import SwiftUI
import Charts

/// Balance history curve view using Swift Charts
/// Corresponds to: src/ui/views/Dashboard/components/BalanceView/
struct BalanceCurveView: View {
    let address: String
    
    @State private var historyData: [OpenAPIService.BalanceHistoryPoint] = []
    @State private var selectedTimeRange: TimeRange = .day
    @State private var isLoading = true
    @State private var selectedPoint: OpenAPIService.BalanceHistoryPoint?
    @State private var error: String?
    
    enum TimeRange: String, CaseIterable {
        case day = "24h"
        case week = "7d"
        case month = "30d"
        case year = "365d"
        
        var label: String {
            switch self {
            case .day: return "24H"
            case .week: return "7D"
            case .month: return "30D"
            case .year: return "1Y"
            }
        }
    }
    
    private var currentValue: Double {
        historyData.last?.usd_value ?? 0
    }
    
    private var changeValue: Double {
        guard let first = historyData.first, let last = historyData.last else { return 0 }
        return last.usd_value - first.usd_value
    }
    
    private var changePercent: Double {
        guard let first = historyData.first, first.usd_value > 0 else { return 0 }
        return changeValue / first.usd_value
    }
    
    private var minValue: Double {
        historyData.map(\.usd_value).min() ?? 0
    }
    
    private var maxValue: Double {
        historyData.map(\.usd_value).max() ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Selected point or current value
            if let point = selectedPoint {
                VStack(spacing: 2) {
                    Text(formatUSD(point.usd_value))
                        .font(.title3).fontWeight(.bold)
                    Text(Date(timeIntervalSince1970: point.timestamp), style: .date)
                        .font(.caption2).foregroundColor(.secondary)
                }
            } else {
                // Change indicator (avoid showing meaningless +$0.00 while loading / no data)
                if !isLoading, historyData.count >= 2 {
                    HStack(spacing: 6) {
                        let isPositive = changeValue >= 0
                        Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.caption2)
                            .foregroundColor(isPositive ? .green : .red)
                        Text("\(isPositive ? "+" : "")\(formatUSD(changeValue))")
                            .font(.caption)
                            .foregroundColor(isPositive ? .green : .red)
                        Text("(\(String(format: "%.2f%%", changePercent * 100)))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Chart
            if #available(iOS 16.0, *) {
                chartView
            } else {
                // Fallback for iOS 15
                fallbackChartView
            }
            
            // Time range selector
            timeRangeSelector
        }
        .task { await loadData() }
    }
    
    // MARK: - Chart (iOS 16+)
    
    @available(iOS 16.0, *)
    private var chartView: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(height: 120)
            } else if historyData.isEmpty {
                Text(L("No data available"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
            } else {
                Chart(historyData, id: \.timestamp) { point in
                    LineMark(
                        x: .value("Time", Date(timeIntervalSince1970: point.timestamp)),
                        y: .value("Value", point.usd_value)
                    )
                    .foregroundStyle(changeValue >= 0 ? Color.green : Color.red)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Time", Date(timeIntervalSince1970: point.timestamp)),
                        yStart: .value("Min", minValue),
                        yEnd: .value("Value", point.usd_value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                (changeValue >= 0 ? Color.green : Color.red).opacity(0.3),
                                (changeValue >= 0 ? Color.green : Color.red).opacity(0.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: minValue * 0.98 ... maxValue * 1.02)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 120)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x
                                        guard let date: Date = proxy.value(atX: x) else { return }
                                        let timestamp = date.timeIntervalSince1970
                                        selectedPoint = historyData.min(by: {
                                            abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp)
                                        })
                                    }
                                    .onEnded { _ in selectedPoint = nil }
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Fallback Chart (iOS 15)
    
    private var fallbackChartView: some View {
        Group {
            if isLoading {
                ProgressView().frame(height: 120)
            } else if historyData.isEmpty {
                Text(L("No data available"))
                    .font(.caption).foregroundColor(.secondary)
                    .frame(height: 120)
            } else {
                // Simple line drawing with Path
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let range = maxValue - minValue
                    let stepX = width / CGFloat(max(historyData.count - 1, 1))
                    
                    Path { path in
                        for (index, point) in historyData.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalizedY = range > 0 ? (point.usd_value - minValue) / range : 0.5
                            let y = height - CGFloat(normalizedY) * height
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(changeValue >= 0 ? Color.green : Color.red, lineWidth: 2)
                }
                .frame(height: 120)
            }
        }
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedTimeRange = range
                    Task { await loadData() }
                }) {
                    Text(range.label)
                        .font(.caption2).fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedTimeRange == range ? Color.blue : Color.clear)
                        .foregroundColor(selectedTimeRange == range ? .white : .secondary)
                        .cornerRadius(6)
                }
            }
        }
        .padding(2)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        error = nil
        do {
            historyData = try await OpenAPIService.shared.getBalanceHistory(
                address: address,
                timeRange: selectedTimeRange.rawValue
            )
        } catch {
            self.error = error.localizedDescription
            historyData = []
        }
        isLoading = false
    }
    
    private func formatUSD(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
