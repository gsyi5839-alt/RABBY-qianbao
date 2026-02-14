import SwiftUI

/// Ecosystem/Ecology entry views - chain-specific DApp ecosystems
/// Corresponds to: More > Ecology section
struct EcologyListView: View {
    @StateObject private var viewModel = EcologyViewModel()
    @State private var selectedCategory: EcologyCategory?
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Category filter
                    categoryFilter

                    // Featured banner
                    if let featured = viewModel.featured.first {
                        ChainEcologyBanner(project: featured)
                    }

                    // Project grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(filteredProjects) { project in
                            NavigationLink(destination: EcologyDetailView(project: project)) {
                                EcologyCard(project: project)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(L("Ecosystem"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search projects")
        }
        .task { await viewModel.loadProjects() }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(EcologyCategory.allCases, id: \.self) { cat in
                    FilterChip(title: cat.rawValue, isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
        }
    }

    private var filteredProjects: [EcologyProject] {
        var projects = viewModel.projects
        if let cat = selectedCategory {
            projects = projects.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            projects = projects.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return projects
    }
}

// MARK: - Ecology Card

struct EcologyCard: View {
    let project: EcologyProject

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: project.iconURL)) { image in
                    image.resizable().frame(width: 36, height: 36).cornerRadius(8)
                } placeholder: {
                    Color(.systemGray4).frame(width: 36, height: 36).cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(project.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(project.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if let tvl = project.tvl {
                Text("TVL: $\(tvl)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Ecology Detail View

struct EcologyDetailView: View {
    let project: EcologyProject

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: project.iconURL)) { image in
                        image.resizable().frame(width: 56, height: 56).cornerRadius(12)
                    } placeholder: {
                        Color(.systemGray4).frame(width: 56, height: 56).cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name).font(.title2).fontWeight(.bold)
                        HStack(spacing: 8) {
                            Text(project.category.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)

                            if project.isAudited {
                                Label(L("Audited"), systemImage: "checkmark.shield.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                Text(project.description)
                    .font(.body)

                // Stats
                if let tvl = project.tvl {
                    HStack {
                        statBox("TVL", "$\(tvl)")
                        statBox("Users", project.userCount ?? "--")
                        statBox("Chain", project.chainName)
                    }
                }

                // Open in DApp Browser
                if let url = URL(string: project.url) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "globe")
                            Text(L("Open in DApp Browser"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statBox(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Chain Ecology Banner

struct ChainEcologyBanner: View {
    let project: EcologyProject

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Featured")).font(.caption).foregroundColor(.white.opacity(0.8))
                    Text(project.name).font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Text(project.description).font(.caption).foregroundColor(.white.opacity(0.8)).lineLimit(2)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Models

enum EcologyCategory: String, CaseIterable {
    case defi = "DeFi"
    case gaming = "Gaming"
    case social = "Social"
    case infrastructure = "Infrastructure"
    case nft = "NFT"
}

struct EcologyProject: Identifiable {
    let id: String
    let name: String
    let description: String
    let chainId: String
    let chainName: String
    let category: EcologyCategory
    let url: String
    let iconURL: String
    let tvl: String?
    let userCount: String?
    let isAudited: Bool
}

// MARK: - View Model

@MainActor
class EcologyViewModel: ObservableObject {
    @Published var projects: [EcologyProject] = []
    @Published var featured: [EcologyProject] = []

    func loadProjects() async {
        // Mock popular ecosystems
        projects = [
            EcologyProject(id: "1", name: "Uniswap", description: "Decentralized exchange protocol", chainId: "1", chainName: "Ethereum", category: .defi, url: "https://app.uniswap.org", iconURL: "", tvl: "5.2B", userCount: "1.2M", isAudited: true),
            EcologyProject(id: "2", name: "Aave", description: "Lending and borrowing protocol", chainId: "1", chainName: "Ethereum", category: .defi, url: "https://app.aave.com", iconURL: "", tvl: "12.1B", userCount: "800K", isAudited: true),
            EcologyProject(id: "3", name: "OpenSea", description: "NFT marketplace", chainId: "1", chainName: "Ethereum", category: .nft, url: "https://opensea.io", iconURL: "", tvl: nil, userCount: "2M", isAudited: true),
            EcologyProject(id: "4", name: "Lido", description: "Liquid staking solution", chainId: "1", chainName: "Ethereum", category: .defi, url: "https://lido.fi", iconURL: "", tvl: "32B", userCount: "300K", isAudited: true),
            EcologyProject(id: "5", name: "GMX", description: "Decentralized perpetual exchange", chainId: "42161", chainName: "Arbitrum", category: .defi, url: "https://gmx.io", iconURL: "", tvl: "600M", userCount: "150K", isAudited: true),
            EcologyProject(id: "6", name: "Sonic", description: "High-performance blockchain ecosystem", chainId: "146", chainName: "Sonic", category: .infrastructure, url: "https://sonic.game", iconURL: "", tvl: "100M", userCount: "50K", isAudited: false),
        ]
        featured = [projects[0]]
    }
}
