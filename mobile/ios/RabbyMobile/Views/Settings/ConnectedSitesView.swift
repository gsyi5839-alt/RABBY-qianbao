import SwiftUI

/// Connected Sites management view
/// Lists all DApp connections (browser + WalletConnect), allows disconnect
struct ConnectedSitesView: View {
    @StateObject private var manager = ConnectedSitesManager.shared
    @State private var searchText = ""
    @State private var filterType: ConnectionFilter = .all
    @State private var selectedSite: ConnectedSiteEntry?

    enum ConnectionFilter: String, CaseIterable {
        case all = "All"
        case dappBrowser = "Browser"
        case walletConnect = "WalletConnect"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter & Search
                VStack(spacing: 8) {
                    Picker(L("Filter"), selection: $filterType) {
                        ForEach(ConnectionFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField(L("Search by name or URL"), text: $searchText)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()

                if filteredSites.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(L("No Connected Sites"))
                            .font(.headline)
                        Text(L("DApps you connect to will appear here"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredSites) { site in
                            Button(action: { selectedSite = site }) {
                                connectedSiteRow(site)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(L("Disconnect"), role: .destructive) {
                                    manager.disconnect(siteId: site.id)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                if !manager.connectedSites.isEmpty {
                    Button(action: { manager.disconnectAll() }) {
                        Text(L("Disconnect All"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle(L("Connected Sites"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedSite) { site in
                ConnectedSiteDetailSheet(site: site)
            }
        }
    }

    private var filteredSites: [ConnectedSiteEntry] {
        var sites = manager.connectedSites
        switch filterType {
        case .dappBrowser:
            sites = sites.filter { $0.connectionType == .dappBrowser }
        case .walletConnect:
            sites = sites.filter { $0.connectionType == .walletConnect }
        case .all: break
        }
        if !searchText.isEmpty {
            sites = sites.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.url.localizedCaseInsensitiveContains(searchText)
            }
        }
        return sites
    }

    private func connectedSiteRow(_ site: ConnectedSiteEntry) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: site.iconURL ?? "")) { image in
                image.resizable().frame(width: 36, height: 36).cornerRadius(8)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "globe").foregroundColor(.white))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(site.name).font(.subheadline).fontWeight(.medium).foregroundColor(.primary)
                    Text(site.connectionType == .walletConnect ? "WC" : "Web")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(site.connectionType == .walletConnect ? Color.blue : Color.green)
                        .cornerRadius(3)
                }
                Text(site.url).font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
        }
    }
}

// MARK: - Site Detail Sheet

struct ConnectedSiteDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = ConnectedSitesManager.shared
    let site: ConnectedSiteEntry

    var body: some View {
        NavigationView {
            List {
                Section(L("Connection Info")) {
                    detailRow("URL", site.url)
                    detailRow("Chain", "Ethereum")
                    detailRow("Type", site.connectionType == .walletConnect ? "WalletConnect" : "DApp Browser")
                    HStack {
                        Text(L("Connected"))
                        Spacer()
                        Text(site.connectedAt, style: .relative).foregroundColor(.secondary)
                    }
                }

                Section(L("Permissions")) {
                    permissionRow("View account address")
                    permissionRow("Request transaction signing")
                    permissionRow("Request message signing")
                }

                Section {
                    Button(role: .destructive) {
                        manager.disconnect(siteId: site.id)
                        dismiss()
                    } label: {
                        Label(L("Disconnect"), systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle(site.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).font(.caption).foregroundColor(.secondary)
        }
    }

    private func permissionRow(_ perm: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
            Text(perm)
        }
    }
}
