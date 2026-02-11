import SwiftUI

/// Activities View - DeFi protocol activities feed
/// Corresponds to: src/ui/views/Activities/
struct ActivitiesView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var tokenManager = TokenManager.shared
    @State private var activities: [ActivityItem] = []
    @State private var isLoading = false
    @State private var selectedCategory: ActivityCategory = .all
    
    enum ActivityCategory: String, CaseIterable {
        case all = "All"
        case defi = "DeFi"
        case nft = "NFT"
        case transfer = "Transfer"
        case approval = "Approval"
    }
    
    struct ActivityItem: Identifiable {
        let id: String
        let type: String
        let protocol_name: String?
        let description: String
        let chain: String
        let timestamp: Date
        let value: String?
        let status: String
        let txHash: String?
        let tokenChanges: [TokenChange]
        
        struct TokenChange {
            let symbol: String
            let amount: String
            let isPositive: Bool
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ActivityCategory.allCases, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedCategory == category ? .semibold : .regular)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                }
                
                if isLoading {
                    Spacer()
                    ProgressView("Loading activities...")
                    Spacer()
                } else if filteredActivities.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle").font(.system(size: 48)).foregroundColor(.gray)
                        Text("No activities found").foregroundColor(.secondary)
                        Text("Your on-chain activities will appear here").font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List(filteredActivities) { activity in
                        activityRow(activity)
                    }
                    .listStyle(.plain)
                    .refreshable { await loadActivities() }
                }
            }
            .navigationTitle("Activities")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { Task { await loadActivities() } }
    }
    
    private var filteredActivities: [ActivityItem] {
        guard selectedCategory != .all else { return activities }
        return activities.filter { $0.type.lowercased().contains(selectedCategory.rawValue.lowercased()) }
    }
    
    private func activityRow(_ activity: ActivityItem) -> some View {
        HStack(spacing: 12) {
            // Type icon
            activityIcon(activity.type)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.description).font(.subheadline).fontWeight(.medium).lineLimit(1)
                    Spacer()
                    Text(activity.timestamp, style: .relative).font(.caption2).foregroundColor(.secondary)
                }
                
                if let proto = activity.protocol_name {
                    Text(proto).font(.caption).foregroundColor(.blue)
                }
                
                // Token changes
                HStack(spacing: 8) {
                    ForEach(activity.tokenChanges.prefix(3), id: \.symbol) { change in
                        Text("\(change.isPositive ? "+" : "-")\(change.amount) \(change.symbol)")
                            .font(.caption)
                            .foregroundColor(change.isPositive ? .green : .red)
                    }
                }
                
                HStack {
                    Text(activity.chain).font(.caption2).foregroundColor(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.systemGray5)).cornerRadius(4)
                    
                    Circle()
                        .fill(activity.status == "success" ? Color.green : activity.status == "failed" ? Color.red : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(activity.status.capitalized).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func activityIcon(_ type: String) -> some View {
        let (icon, color): (String, Color) = {
            switch type.lowercased() {
            case let t where t.contains("swap"): return ("arrow.triangle.2.circlepath", .blue)
            case let t where t.contains("bridge"): return ("link", .purple)
            case let t where t.contains("lend"), let t where t.contains("borrow"): return ("building.columns", .orange)
            case let t where t.contains("stake"): return ("lock.fill", .green)
            case let t where t.contains("nft"): return ("photo.fill", .pink)
            case let t where t.contains("approve"): return ("checkmark.shield", .yellow)
            case let t where t.contains("send"), let t where t.contains("transfer"): return ("arrow.up.right", .red)
            case let t where t.contains("receive"): return ("arrow.down.left", .green)
            default: return ("circle.grid.2x2", .gray)
            }
        }()
        
        return Image(systemName: icon)
            .font(.body).foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(color)
            .cornerRadius(8)
    }
    
    private func loadActivities() async {
        guard let address = keyringManager.currentAccount?.address else { return }
        isLoading = activities.isEmpty
        do {
            let result = try await OpenAPIService.shared.getActivities(address: address)
            activities = result.map { item in
                ActivityItem(
                    id: item.id, type: item.type, protocol_name: item.protocolName,
                    description: item.description, chain: item.chain,
                    timestamp: Date(timeIntervalSince1970: item.timestamp), value: item.value,
                    status: item.status, txHash: item.txHash,
                    tokenChanges: item.tokenChanges.map {
                        ActivityItem.TokenChange(symbol: $0.symbol, amount: $0.amount, isPositive: $0.isPositive)
                    }
                )
            }
        } catch {
            print("Failed to load activities: \(error)")
        }
        isLoading = false
    }
}
