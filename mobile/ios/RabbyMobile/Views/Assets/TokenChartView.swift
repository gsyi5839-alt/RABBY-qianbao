import SwiftUI

// MARK: - Data Models

/// A single price data point on the chart
struct PricePoint: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let price: Double
}

/// Available chart time periods
enum ChartPeriod: String, CaseIterable {
    case hour = "1H"
    case day = "24H"
    case week = "7D"
    case month = "30D"
    case year = "1Y"
    case all = "ALL"

    /// Number of seconds covered by this period (used for mock data generation)
    var timeInterval: TimeInterval {
        switch self {
        case .hour:  return 3600
        case .day:   return 86400
        case .week:  return 604800
        case .month: return 2592000
        case .year:  return 31536000
        case .all:   return 94608000 // ~3 years
        }
    }

    /// Number of data points to generate / expect
    var dataPointCount: Int {
        switch self {
        case .hour:  return 60
        case .day:   return 96
        case .week:  return 168
        case .month: return 120
        case .year:  return 365
        case .all:   return 365
        }
    }
}

// MARK: - TokenChartView

/// Token price chart with interactive crosshair and period selector.
/// Uses pure SwiftUI drawing (Path + Canvas) without third-party chart libraries.
///
/// Corresponds to: src/ui/views/Dashboard/components/TokenDetailPopup/ChartSection
struct TokenChartView: View {
    let tokenId: String       // token contract address
    let chainId: String
    let tokenSymbol: String

    @State private var selectedPeriod: ChartPeriod = .day
    @State private var priceData: [PricePoint] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPoint: PricePoint?
    @State private var animationProgress: CGFloat = 0

    // MARK: - Computed Properties

    private var currentPrice: Double {
        priceData.last?.price ?? 0
    }

    private var firstPrice: Double {
        priceData.first?.price ?? 0
    }

    private var priceChange: Double {
        guard firstPrice > 0 else { return 0 }
        return (currentPrice - firstPrice) / firstPrice
    }

    private var isPositiveChange: Bool {
        priceChange >= 0
    }

    private var trendColor: Color {
        isPositiveChange ? .green : .red
    }

    private var minPrice: Double {
        priceData.map(\.price).min() ?? 0
    }

    private var maxPrice: Double {
        priceData.map(\.price).max() ?? 0
    }

    private var priceRange: Double {
        let range = maxPrice - minPrice
        return range > 0 ? range : 1
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Price display area
            priceDisplaySection

            // Chart area
            chartSection
                .frame(height: 200)

            // Period selector
            periodSelector
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .task {
            await loadPriceData()
        }
    }

    // MARK: - Price Display

    private var priceDisplaySection: some View {
        VStack(spacing: 4) {
            if let point = selectedPoint {
                // Show selected point info
                Text(formatPrice(point.price))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(formatDate(point.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Show current price + change
                Text(formatPrice(currentPrice))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                if !priceData.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: isPositiveChange ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.caption2)
                        Text(String(format: "%@%.2f%%", isPositiveChange ? "+" : "", priceChange * 100))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(trendColor)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: selectedPoint?.id)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button(L("Retry")) {
                        Task { await loadPriceData() }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            } else if priceData.count < 2 {
                Text(L("Not enough data"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                chartCanvas
            }
        }
    }

    // MARK: - Chart Canvas with Touch Interaction

    private var chartCanvas: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Gradient fill under the line
                chartGradientFill(width: width, height: height)
                    .clipShape(
                        ChartClipShape(
                            data: priceData,
                            minPrice: minPrice,
                            priceRange: priceRange,
                            width: width,
                            height: height,
                            animationProgress: animationProgress
                        )
                    )

                // Price line
                chartLine(width: width, height: height)
                    .trim(from: 0, to: animationProgress)
                    .stroke(trendColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Crosshair overlay (when point selected)
                if let point = selectedPoint {
                    crosshairOverlay(point: point, width: width, height: height)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(at: value.location, in: CGSize(width: width, height: height))
                    }
                    .onEnded { _ in
                        selectedPoint = nil
                    }
            )
        }
    }

    // MARK: - Chart Drawing Helpers

    /// Build the smooth curve Path for the price line
    private func chartLine(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            guard priceData.count >= 2 else { return }

            let points = priceData.enumerated().map { (index, point) -> CGPoint in
                let x = CGFloat(index) / CGFloat(priceData.count - 1) * width
                let normalizedY = (point.price - minPrice) / priceRange
                let y = height - normalizedY * height
                return CGPoint(x: x, y: y)
            }

            path.move(to: points[0])

            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let midX = (prev.x + curr.x) / 2
                path.addCurve(
                    to: curr,
                    control1: CGPoint(x: midX, y: prev.y),
                    control2: CGPoint(x: midX, y: curr.y)
                )
            }
        }
    }

    /// Gradient fill from trendColor to clear
    private func chartGradientFill(width: CGFloat, height: CGFloat) -> some View {
        LinearGradient(
            gradient: Gradient(colors: [
                trendColor.opacity(0.3),
                trendColor.opacity(0.05),
                trendColor.opacity(0.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Crosshair overlay at selected price point
    private func crosshairOverlay(point: PricePoint, width: CGFloat, height: CGFloat) -> some View {
        let index = priceData.firstIndex(where: { $0.id == point.id }) ?? 0
        let x = CGFloat(index) / CGFloat(max(priceData.count - 1, 1)) * width
        let normalizedY = (point.price - minPrice) / priceRange
        let y = height - normalizedY * height

        return ZStack {
            // Vertical line
            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
            .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

            // Horizontal line
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

            // Dot at intersection
            Circle()
                .fill(trendColor)
                .frame(width: 10, height: 10)
                .shadow(color: trendColor.opacity(0.4), radius: 4, x: 0, y: 0)
                .position(x: x, y: y)
        }
    }

    // MARK: - Touch Handling

    private func handleDrag(at location: CGPoint, in size: CGSize) {
        guard !priceData.isEmpty else { return }

        let xFraction = max(0, min(1, location.x / size.width))
        let index = Int(round(xFraction * CGFloat(priceData.count - 1)))
        let clampedIndex = max(0, min(priceData.count - 1, index))

        let newPoint = priceData[clampedIndex]
        if selectedPoint?.id != newPoint.id {
            selectedPoint = newPoint
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(ChartPeriod.allCases, id: \.self) { period in
                Button(action: {
                    guard selectedPeriod != period else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                    Task { await loadPriceData() }
                }) {
                    Text(period.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedPeriod == period
                                ? Color.blue
                                : Color.clear
                        )
                        .foregroundColor(
                            selectedPeriod == period
                                ? .white
                                : .secondary
                        )
                        .cornerRadius(6)
                }
            }
        }
        .padding(2)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Data Loading

    private func loadPriceData() async {
        isLoading = true
        errorMessage = nil
        selectedPoint = nil
        animationProgress = 0

        do {
            let data: [PricePoint] = try await fetchPriceChart(
                tokenId: tokenId,
                chainId: chainId,
                period: selectedPeriod
            )

            await MainActor.run {
                self.priceData = data
                self.isLoading = false
            }

            // Animate the chart drawing from left to right
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load price data"
                self.isLoading = false
            }
        }
    }

    /// Attempt to fetch from OpenAPI; fall back to simulated data for UI development
    private func fetchPriceChart(tokenId: String, chainId: String, period: ChartPeriod) async throws -> [PricePoint] {
        // Try the real API first
        do {
            let rawPoints: [[Double]] = try await OpenAPIService.shared.get(
                "/v1/token/price_chart",
                params: [
                    "id": tokenId,
                    "chain_id": chainId,
                    "period": period.rawValue.lowercased()
                ]
            )
            // API returns [[timestamp, price], ...] pairs
            return rawPoints.map { pair in
                PricePoint(timestamp: pair[0], price: pair.count > 1 ? pair[1] : 0)
            }
        } catch {
            // API unavailable -- generate mock data for UI development
            return generateMockData(period: period)
        }
    }

    // MARK: - Mock Data Generation

    private func generateMockData(period: ChartPeriod) -> [PricePoint] {
        let now = Date().timeIntervalSince1970
        let count = period.dataPointCount
        let interval = period.timeInterval / Double(count)

        // Use a deterministic seed based on tokenId + period for consistent results
        let seedHash = abs((tokenId + period.rawValue).hashValue)
        var rng = SeededRNG(seed: UInt64(seedHash))

        // Base price from symbol hash (small but realistic)
        let basePriceRaw = Double((tokenSymbol.hashValue & 0xFFFF)) / 100.0
        let basePrice = max(basePriceRaw, 0.01)

        var price = basePrice
        var points: [PricePoint] = []

        for i in 0..<count {
            let timestamp = now - period.timeInterval + Double(i) * interval
            // Random walk with slight upward drift
            let change = (rng.nextDouble() - 0.48) * basePrice * 0.03
            price = max(price + change, basePrice * 0.5)
            points.append(PricePoint(timestamp: timestamp, price: price))
        }

        return points
    }

    // MARK: - Formatting Helpers

    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        if value < 0.01 {
            formatter.maximumFractionDigits = 8
            formatter.minimumFractionDigits = 4
        } else if value < 1 {
            formatter.maximumFractionDigits = 6
            formatter.minimumFractionDigits = 2
        } else {
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
        }
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .hour:
            formatter.dateFormat = "HH:mm"
        case .day:
            formatter.dateFormat = "HH:mm"
        case .week:
            formatter.dateFormat = "EEE, MMM d HH:mm"
        case .month:
            formatter.dateFormat = "MMM d"
        case .year, .all:
            formatter.dateFormat = "MMM d, yyyy"
        }

        return formatter.string(from: date)
    }
}

// MARK: - Chart Clip Shape (for gradient fill area)

/// Custom Shape that closes the chart line path to form a filled area
private struct ChartClipShape: Shape {
    let data: [PricePoint]
    let minPrice: Double
    let priceRange: Double
    let width: CGFloat
    let height: CGFloat
    let animationProgress: CGFloat

    var animatableData: CGFloat {
        get { animationProgress }
        set { /* read-only for clip shape */ }
    }

    func path(in rect: CGRect) -> Path {
        guard data.count >= 2 else { return Path() }

        let visibleCount = max(2, Int(CGFloat(data.count) * animationProgress))
        let visibleData = Array(data.prefix(visibleCount))

        var path = Path()
        let points = visibleData.enumerated().map { (index, point) -> CGPoint in
            let x = CGFloat(index) / CGFloat(data.count - 1) * width
            let normalizedY = (point.price - minPrice) / priceRange
            let y = height - normalizedY * height
            return CGPoint(x: x, y: y)
        }

        guard let firstPoint = points.first, let lastPoint = points.last else {
            return path
        }

        path.move(to: firstPoint)

        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let midX = (prev.x + curr.x) / 2
            path.addCurve(
                to: curr,
                control1: CGPoint(x: midX, y: prev.y),
                control2: CGPoint(x: midX, y: curr.y)
            )
        }

        // Close the shape along the bottom
        path.addLine(to: CGPoint(x: lastPoint.x, y: height))
        path.addLine(to: CGPoint(x: firstPoint.x, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Seeded Random Number Generator (deterministic mock data)

private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextDouble() -> Double {
        return Double(next() % 10000) / 10000.0
    }
}
