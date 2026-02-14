import Foundation
import Combine

// MARK: - ConnectedSite Model

/// Unified model representing a connected DApp site, regardless of connection method.
/// Aggregates connections from both the in-app DApp browser and WalletConnect sessions.
struct ConnectedSiteEntry: Codable, Identifiable, Equatable {
    let id: String
    let url: String
    let name: String
    let iconURL: String?
    var chainId: String
    let connectedAt: Date
    var permissions: [SitePermission]
    let connectionType: ConnectionType
    var connectedAddress: String?

    /// How the DApp was connected
    enum ConnectionType: String, Codable, CaseIterable {
        case dappBrowser = "DApp Browser"
        case walletConnect = "WalletConnect"

        var icon: String {
            switch self {
            case .dappBrowser: return "globe"
            case .walletConnect: return "link.circle"
            }
        }
    }

    /// Granular permission granted to the site
    enum SitePermission: String, Codable, CaseIterable {
        case viewAddress = "View wallet address"
        case requestTransactions = "Request transaction approval"
        case signMessages = "Sign messages"
        case suggestTokens = "Suggest token additions"
        case switchChain = "Switch chain"

        var icon: String {
            switch self {
            case .viewAddress: return "eye"
            case .requestTransactions: return "arrow.up.doc"
            case .signMessages: return "signature"
            case .suggestTokens: return "plus.circle"
            case .switchChain: return "arrow.triangle.swap"
            }
        }
    }

    static func == (lhs: ConnectedSiteEntry, rhs: ConnectedSiteEntry) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - ConnectedSitesManager

/// Central manager that unifies connected-site state from DAppBrowser and WalletConnect.
///
/// Data flow:
/// - DApp Browser connections arrive via `DAppPermissionManager` (which is called from `DAppConnectSheet`).
///   This manager listens to `DAppPermissionManager.connectedSites` changes via Combine.
/// - WalletConnect connections arrive via `WalletConnectManager.sessions`.
///   This manager listens to `WalletConnectManager.$sessions` via Combine.
/// - Both sources are merged into a single `connectedSites` array that the UI observes.
/// - Mutations (disconnect, update permissions, switch chain) are forwarded to the
///   appropriate underlying manager so the source of truth stays consistent.
/// - The merged list is also persisted via `StorageManager` for offline access.
@MainActor
class ConnectedSitesManager: ObservableObject {
    static let shared = ConnectedSitesManager()

    // MARK: - Published State

    /// Unified list of all connected sites (DApp Browser + WalletConnect)
    @Published var connectedSites: [ConnectedSiteEntry] = []

    // MARK: - Combine Publishers

    /// Publisher that emits whenever a site is connected
    let siteConnectedPublisher = PassthroughSubject<ConnectedSiteEntry, Never>()

    /// Publisher that emits the id of a site that was disconnected
    let siteDisconnectedPublisher = PassthroughSubject<String, Never>()

    /// Publisher that emits whenever the full list changes
    var sitesPublisher: AnyPublisher<[ConnectedSiteEntry], Never> {
        $connectedSites.eraseToAnyPublisher()
    }

    // MARK: - Dependencies

    private let storage = StorageManager.shared
    private let wcManager = WalletConnectManager.shared
    private let permManager = DAppPermissionManager.shared

    private let storageKey = "rabby_connected_sites_unified"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        loadFromStorage()
        subscribeToSources()
    }

    // MARK: - Public API

    /// Register a new connected site (called from DApp Browser flow).
    /// If a site with the same id already exists, it is updated.
    func connect(site: ConnectedSiteEntry) {
        if let index = connectedSites.firstIndex(where: { $0.id == site.id }) {
            connectedSites[index] = site
        } else {
            connectedSites.append(site)
        }
        persist()
        siteConnectedPublisher.send(site)
    }

    /// Convenience: build and register a DApp Browser connected site from basic info.
    func connectDAppBrowser(
        url: String,
        name: String,
        iconURL: String?,
        chainId: String,
        address: String?,
        permissions: [ConnectedSiteEntry.SitePermission] = ConnectedSiteEntry.SitePermission.allCases
    ) {
        let site = ConnectedSiteEntry(
            id: hostFromURL(url),
            url: url,
            name: name,
            iconURL: iconURL,
            chainId: chainId,
            connectedAt: Date(),
            permissions: permissions,
            connectionType: .dappBrowser,
            connectedAddress: address
        )
        connect(site: site)
    }

    /// Disconnect a single site by its id. Also forwards to the underlying manager.
    func disconnect(siteId: String) {
        guard let site = connectedSites.first(where: { $0.id == siteId }) else { return }

        switch site.connectionType {
        case .dappBrowser:
            // Remove from DAppPermissionManager (try both full URL and host-only origin)
            permManager.removeSite(origin: site.url)
            permManager.removeSite(origin: hostFromURL(site.url))

        case .walletConnect:
            // The WCSession topic is stored as the ConnectedSiteEntry id for WC entries
            Task {
                await wcManager.disconnectSession(site.id)
            }
        }

        connectedSites.removeAll { $0.id == siteId }
        persist()
        siteDisconnectedPublisher.send(siteId)
    }

    /// Disconnect all sites. Clears both DApp Browser and WalletConnect connections.
    func disconnectAll() {
        // Forward to underlying managers
        permManager.disconnectAll()
        Task {
            await wcManager.disconnectAllSessions()
        }

        let ids = connectedSites.map { $0.id }
        connectedSites.removeAll()
        persist()

        for id in ids {
            siteDisconnectedPublisher.send(id)
        }
    }

    /// Update the permissions granted to a specific site.
    func updatePermissions(siteId: String, permissions: [ConnectedSiteEntry.SitePermission]) {
        guard let index = connectedSites.firstIndex(where: { $0.id == siteId }) else { return }
        connectedSites[index].permissions = permissions
        persist()
    }

    /// Switch the chain associated with a connected site.
    func switchChain(siteId: String, newChainId: String) {
        guard let index = connectedSites.firstIndex(where: { $0.id == siteId }) else { return }
        connectedSites[index].chainId = newChainId

        // Also update in DAppPermissionManager if it is a browser connection
        if connectedSites[index].connectionType == .dappBrowser {
            let origin = connectedSites[index].url
            permManager.setSiteChain(origin: origin, chain: newChainId)
            permManager.setSiteChain(origin: hostFromURL(origin), chain: newChainId)
        }
        persist()
    }

    /// Switch the connected address for a site.
    func switchAddress(siteId: String, newAddress: String) {
        guard let index = connectedSites.firstIndex(where: { $0.id == siteId }) else { return }
        connectedSites[index].connectedAddress = newAddress
        persist()
    }

    /// Return sites filtered by connection type.
    func sites(ofType type: ConnectedSiteEntry.ConnectionType) -> [ConnectedSiteEntry] {
        connectedSites.filter { $0.connectionType == type }
    }

    /// Search sites by name or URL.
    func search(query: String) -> [ConnectedSiteEntry] {
        guard !query.isEmpty else { return connectedSites }
        let q = query.lowercased()
        return connectedSites.filter {
            $0.name.lowercased().contains(q) || $0.url.lowercased().contains(q)
        }
    }

    // MARK: - Combine Subscriptions

    /// Subscribe to changes from both DAppPermissionManager and WalletConnectManager
    /// to keep the unified list in sync.
    private func subscribeToSources() {
        // Listen to DAppPermissionManager changes
        permManager.$connectedSites
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dappSites in
                guard let self else { return }
                self.syncDAppBrowserSites(dappSites)
            }
            .store(in: &cancellables)

        // Listen to WalletConnectManager session changes
        wcManager.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] wcSessions in
                guard let self else { return }
                self.syncWalletConnectSessions(wcSessions)
            }
            .store(in: &cancellables)

        // Also listen for WC session deletion notifications for immediate removal
        NotificationCenter.default.publisher(for: .wcSessionDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let topic = notification.userInfo?["topic"] as? String else { return }
                if self.connectedSites.contains(where: { $0.id == topic }) {
                    self.connectedSites.removeAll { $0.id == topic }
                    self.persist()
                    self.siteDisconnectedPublisher.send(topic)
                }
            }
            .store(in: &cancellables)
    }

    /// Merge DApp Browser connected sites into the unified list.
    /// New browser sites are added; removed browser sites are pruned.
    private func syncDAppBrowserSites(_ dappSites: [DAppPermissionManager.ConnectedSite]) {
        let activeBrowserSites = dappSites.filter { $0.isConnected }

        // Build a set of current browser-origin ids in the unified list
        let existingBrowserIds = Set(
            connectedSites
                .filter { $0.connectionType == .dappBrowser }
                .map { $0.id }
        )

        // Add new browser sites not yet in the unified list
        for site in activeBrowserSites {
            let siteId = site.origin
            if !existingBrowserIds.contains(siteId) {
                let entry = ConnectedSiteEntry(
                    id: siteId,
                    url: site.origin,
                    name: site.name,
                    iconURL: site.icon,
                    chainId: site.chain,
                    connectedAt: site.connectedAt,
                    permissions: ConnectedSiteEntry.SitePermission.allCases,
                    connectionType: .dappBrowser,
                    connectedAddress: site.account?.address
                )
                connectedSites.append(entry)
                siteConnectedPublisher.send(entry)
            }
        }

        // Remove browser sites that are no longer active in DAppPermissionManager
        let activeBrowserOrigins = Set(activeBrowserSites.map { $0.origin })
        connectedSites.removeAll { site in
            site.connectionType == .dappBrowser && !activeBrowserOrigins.contains(site.id)
        }

        persist()
    }

    /// Merge WalletConnect sessions into the unified list.
    /// New sessions are added; expired/disconnected sessions are pruned.
    private func syncWalletConnectSessions(_ wcSessions: [WalletConnectManager.WCSession]) {
        let existingWCIds = Set(
            connectedSites
                .filter { $0.connectionType == .walletConnect }
                .map { $0.id }
        )

        // Add new WC sessions not yet in the unified list
        for session in wcSessions {
            if !existingWCIds.contains(session.id) {
                // Extract numeric chain id from CAIP-2 format (eip155:1 -> 1)
                let chainId = session.chains.first.flatMap { chain -> String? in
                    let parts = chain.split(separator: ":")
                    return parts.count == 2 ? String(parts[1]) : nil
                } ?? "1"

                let entry = ConnectedSiteEntry(
                    id: session.id,
                    url: session.peerUrl,
                    name: session.peerName,
                    iconURL: session.peerIcon,
                    chainId: chainId,
                    connectedAt: session.createdAt,
                    permissions: [.viewAddress, .requestTransactions, .signMessages, .switchChain],
                    connectionType: .walletConnect,
                    connectedAddress: session.accounts.first
                )
                connectedSites.append(entry)
                siteConnectedPublisher.send(entry)
            }
        }

        // Remove WC entries whose session no longer exists
        let activeWCIds = Set(wcSessions.map { $0.id })
        let removedIds = connectedSites
            .filter { $0.connectionType == .walletConnect && !activeWCIds.contains($0.id) }
            .map { $0.id }

        connectedSites.removeAll { site in
            site.connectionType == .walletConnect && !activeWCIds.contains(site.id)
        }

        for id in removedIds {
            siteDisconnectedPublisher.send(id)
        }

        persist()
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        if let data = storage.getData(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ConnectedSiteEntry].self, from: data) {
            connectedSites = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(connectedSites) {
            storage.setData(data, forKey: storageKey)
        }
    }

    // MARK: - Helpers

    private func hostFromURL(_ urlString: String) -> String {
        if let url = URL(string: urlString), let host = url.host {
            return host
        }
        var cleaned = urlString
        if cleaned.hasPrefix("https://") { cleaned = String(cleaned.dropFirst(8)) }
        if cleaned.hasPrefix("http://") { cleaned = String(cleaned.dropFirst(7)) }
        if let slashIdx = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[..<slashIdx])
        }
        return cleaned
    }
}
