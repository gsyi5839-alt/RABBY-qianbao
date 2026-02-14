import Foundation
import Combine
import BigInt
import WalletConnectSwiftV2

/// Typealias to disambiguate WalletConnect Account from RabbyMobile.Account
private typealias WCAccount = WalletConnectSwiftV2.Account

/// WalletConnect Manager - Support WalletConnect v2 protocol for DApp connections
/// Equivalent to Web version's WalletConnect integration
@MainActor
class WalletConnectManager: ObservableObject {
    static let shared = WalletConnectManager()

    @Published var sessions: [WCSession] = []
    @Published var pendingProposals: [WCProposal] = []
    @Published var pendingRequests: [WCRequest] = []

    private let storage = StorageManager.shared
    private let keyringManager = KeyringManager.shared
    private let chainManager = ChainManager.shared

    private let sessionsKey = "rabby_wc_sessions"
    private let maxDuration: TimeInterval = 3600 // 1 hour

    private var cancellables = Set<AnyCancellable>()

    // WalletConnect v2 configuration
    struct WCConfig {
        static let projectId = "ed21a1293590bdc995404dff7e033f04" // Rabby project ID
        static let name = "Rabby Wallet"
        static let description = "The game-changing wallet for Ethereum and all EVM chains"
        static let url = "https://rabby.io"
        static let icons = ["https://static-assets.rabby.io/files/122da969-da58-42e9-ab39-0a8dd38d94b8.png"]
    }

    // MARK: - Models

    struct WCSession: Codable, Identifiable {
        let id: String
        let topic: String
        let peerName: String
        let peerUrl: String
        let peerIcon: String?
        let accounts: [String]
        let chains: [String]
        let createdAt: Date
        var lastUsedAt: Date
    }

    struct WCProposal: Identifiable {
        let id: String
        let proposer: Proposer
        let requiredNamespaces: [String: Namespace]
        let optionalNamespaces: [String: Namespace]?

        struct Proposer {
            let name: String
            let description: String
            let url: String
            let icons: [String]
        }

        struct Namespace {
            let chains: [String]
            let methods: [String]
            let events: [String]
        }
    }

    struct WCRequest: Identifiable {
        let id: String
        let topic: String
        let method: String
        let params: Any
        let chainId: String
    }

    // MARK: - Initialization

    private init() {
        loadSessions()
        configureWalletConnect()
    }

    // MARK: - WalletConnect SDK Configuration

    /// Configure the WalletConnect Sign client and subscribe to events
    private func configureWalletConnect() {
        let metadata = AppMetadata(
            name: WCConfig.name,
            description: WCConfig.description,
            url: WCConfig.url,
            icons: WCConfig.icons,
            redirect: try! AppMetadata.Redirect(native: "rabby://wc", universal: nil)
        )

        // Configure Pair client
        Pair.configure(metadata: metadata)

        // Subscribe to session proposals from DApps
        Sign.instance.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] proposalContext in
                guard let self else { return }
                Task { @MainActor in
                    self.handleSessionProposal(proposalContext.proposal)
                }
            }
            .store(in: &cancellables)

        // Subscribe to session requests (signing, transactions, etc.)
        Sign.instance.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requestContext in
                guard let self else { return }
                Task { @MainActor in
                    await self.handleSessionRequest(requestContext.request)
                }
            }
            .store(in: &cancellables)

        // Subscribe to session deletions (DApp disconnected)
        Sign.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (topic, _) in
                guard let self else { return }
                Task { @MainActor in
                    self.removeSessionByTopic(topic)
                }
            }
            .store(in: &cancellables)

        // Subscribe to session settlements (new session established)
        Sign.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self else { return }
                Task { @MainActor in
                    self.didSettle(session: session)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Pairing & Connection

    /// Connect to DApp via WalletConnect URI
    /// Parses the WC v2 URI and initiates pairing with the relay server.
    func connect(uri: String) async throws {
        // Validate and parse WalletConnect URI (format: wc:topic@2?relay-protocol=irn&symKey=...)
        guard uri.hasPrefix("wc:") else {
            throw WCError.invalidURI
        }

        guard let walletConnectURI = try? WalletConnectURI(uriString: uri) else {
            print("[WC] Invalid WalletConnect URI format")
            throw WCError.invalidURI
        }

        print("[WC] Pairing with URI: \(uri.prefix(30))...")

        do {
            try await Pair.instance.pair(uri: walletConnectURI)
            print("[WC] Pairing successful, waiting for session proposal...")
        } catch {
            print("[WC] Pairing failed: \(error.localizedDescription)")
            throw WCError.connectionFailed
        }
    }

    /// Pair with DApp via WalletConnect URI (alias for connect)
    func pair(uri: String) async throws {
        try await connect(uri: uri)
    }

    // MARK: - Session Proposal Handling

    /// Process an incoming session proposal from a DApp.
    /// Extracts the required/optional namespaces and creates a WCProposal for user approval.
    private func handleSessionProposal(_ proposal: Session.Proposal) {
        // Build required namespaces
        var requiredNS: [String: WCProposal.Namespace] = [:]
        for (key, namespace) in proposal.requiredNamespaces {
            let chains = namespace.chains?.map { $0.absoluteString } ?? []
            requiredNS[key] = WCProposal.Namespace(
                chains: chains,
                methods: Array(namespace.methods),
                events: Array(namespace.events)
            )
        }

        // Build optional namespaces
        var optionalNS: [String: WCProposal.Namespace]?
        if let optNamespaces = proposal.optionalNamespaces, !optNamespaces.isEmpty {
            var ns: [String: WCProposal.Namespace] = [:]
            for (key, namespace) in optNamespaces {
                let chains = namespace.chains?.map { $0.absoluteString } ?? []
                ns[key] = WCProposal.Namespace(
                    chains: chains,
                    methods: Array(namespace.methods),
                    events: Array(namespace.events)
                )
            }
            optionalNS = ns
        }

        let peerMetadata = proposal.proposer
        let wcProposal = WCProposal(
            id: proposal.id,
            proposer: WCProposal.Proposer(
                name: peerMetadata.name,
                description: peerMetadata.description,
                url: peerMetadata.url,
                icons: peerMetadata.icons
            ),
            requiredNamespaces: requiredNS,
            optionalNamespaces: optionalNS
        )

        pendingProposals.append(wcProposal)

        // Post a notification so the UI can react
        NotificationCenter.default.post(
            name: .wcSessionProposalReceived,
            object: nil,
            userInfo: ["proposalId": wcProposal.id]
        )

        // Auto-approve if the user has an active account (convenience behavior).
        // In production, this should always present UI for explicit user consent.
        if let currentAccount = keyringManager.currentAccount {
            Task {
                try? await autoApproveProposal(wcProposal, address: currentAccount.address)
            }
        }
    }

    /// Automatically approve a proposal with the current account address.
    /// Only called when auto-approve is appropriate (single-account wallet scenario).
    private func autoApproveProposal(_ proposal: WCProposal, address: String) async throws {
        // Collect all requested chain IDs (CAIP-2 format: eip155:1, eip155:137, etc.)
        var allChainIds: [String] = []
        for (_, ns) in proposal.requiredNamespaces {
            allChainIds.append(contentsOf: ns.chains)
        }
        if let optNS = proposal.optionalNamespaces {
            for (_, ns) in optNS {
                allChainIds.append(contentsOf: ns.chains)
            }
        }

        // Deduplicate and default to eip155:1 if empty
        let uniqueChains = Array(Set(allChainIds.isEmpty ? ["eip155:1"] : allChainIds))

        // Build CAIP-10 accounts (e.g. eip155:1:0xabc...)
        let caipAccounts = uniqueChains.map { "\($0):\(address)" }

        try await approveSession(proposal.id, accounts: caipAccounts, chains: uniqueChains)
    }

    /// Approve session proposal — constructs the session namespaces and calls the SDK approve.
    func approveSession(_ proposalId: String, accounts: [String], chains: [String]) async throws {
        guard let proposal = pendingProposals.first(where: { $0.id == proposalId }) else {
            throw WCError.proposalNotFound
        }

        // Build SessionNamespace for the "eip155" key.
        // accounts are in CAIP-10 format: eip155:<chainId>:<address>
        // chains are in CAIP-2 format: eip155:<chainId>
        let blockchainAccounts: [WCAccount] = accounts.compactMap {
            WCAccount($0)
        }
        let blockchainChains: [Blockchain] = chains.compactMap {
            Blockchain($0)
        }

        // Standard EIP-155 methods and events that Rabby supports
        let supportedMethods: Set<String> = [
            "eth_sendTransaction",
            "eth_sign",
            "personal_sign",
            "eth_signTypedData",
            "eth_signTypedData_v3",
            "eth_signTypedData_v4",
            "wallet_switchEthereumChain",
            "wallet_addEthereumChain"
        ]

        let supportedEvents: Set<String> = [
            "chainChanged",
            "accountsChanged"
        ]

        // Merge required methods/events with our supported set
        var mergedMethods = supportedMethods
        var mergedEvents = supportedEvents
        for (_, ns) in proposal.requiredNamespaces {
            mergedMethods.formUnion(ns.methods)
            mergedEvents.formUnion(ns.events)
        }

        let sessionNamespace = SessionNamespace(
            chains: blockchainChains,
            accounts: blockchainAccounts,
            methods: mergedMethods,
            events: mergedEvents
        )

        let sessionNamespaces: [String: SessionNamespace] = ["eip155": sessionNamespace]

        do {
            _ = try await Sign.instance.approve(
                proposalId: proposalId,
                namespaces: sessionNamespaces
            )
            print("[WC] Session approved for proposal: \(proposalId)")
        } catch {
            print("[WC] Failed to approve session: \(error.localizedDescription)")
            throw WCError.connectionFailed
        }

        // Remove from pending
        pendingProposals.removeAll { $0.id == proposalId }
    }

    /// Reject session proposal
    func rejectSession(_ proposalId: String) async {
        do {
            try await Sign.instance.rejectSession(
                proposalId: proposalId,
                reason: .userRejected
            )
        } catch {
            print("[WC] Failed to reject session: \(error.localizedDescription)")
        }
        pendingProposals.removeAll { $0.id == proposalId }
    }

    /// Called when a session is successfully settled by the SDK.
    private func didSettle(session: Session) {
        // Extract accounts and chains from the settled session namespaces
        var allAccounts: [String] = []
        var allChains: [String] = []

        for (_, namespace) in session.namespaces {
            for account in namespace.accounts {
                allAccounts.append(account.address)
            }
            if let chains = namespace.chains {
                allChains.append(contentsOf: chains.map { $0.absoluteString })
            }
        }

        let peerMeta = session.peer
        let wcSession = WCSession(
            id: session.topic,
            topic: session.topic,
            peerName: peerMeta.name,
            peerUrl: peerMeta.url,
            peerIcon: peerMeta.icons.first,
            accounts: Array(Set(allAccounts)),
            chains: Array(Set(allChains)),
            createdAt: Date(),
            lastUsedAt: Date()
        )

        // Replace or insert
        if let idx = sessions.firstIndex(where: { $0.topic == session.topic }) {
            sessions[idx] = wcSession
        } else {
            sessions.append(wcSession)
        }

        saveSessions()

        NotificationCenter.default.post(
            name: .wcSessionSettled,
            object: nil,
            userInfo: ["topic": session.topic]
        )

        print("[WC] Session settled: \(peerMeta.name) — topic: \(session.topic)")
    }

    // MARK: - Session Request Handling

    /// Route an incoming session request to the appropriate handler based on the RPC method.
    private func handleSessionRequest(_ request: Request) async {
        let method = request.method
        let topic = request.topic
        let _ = request.chainId.absoluteString

        print("[WC] Received request: \(method) on topic \(topic)")

        // Update session lastUsedAt
        if let idx = sessions.firstIndex(where: { $0.topic == topic }) {
            sessions[idx].lastUsedAt = Date()
            saveSessions()
        }

        do {
            let response: WalletConnectSwiftV2.AnyCodable

            switch method {
            case "eth_sendTransaction":
                let txHash = try await handleSendTransaction(request)
                response = WalletConnectSwiftV2.AnyCodable(txHash)

            case "personal_sign":
                let signature = try await handlePersonalSign(request)
                response = WalletConnectSwiftV2.AnyCodable(signature)

            case "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
                let signature = try await handleSignTypedData(request)
                response = WalletConnectSwiftV2.AnyCodable(signature)

            case "eth_sign":
                // eth_sign is dangerous — reject by default with a clear message.
                throw WCError.dangerousSignRejected

            case "wallet_switchEthereumChain":
                try await handleSwitchEthereumChain(request)
                response = WalletConnectSwiftV2.AnyCodable(nil as String?)

            case "wallet_addEthereumChain":
                // Acknowledge but do not add custom chains automatically
                response = WalletConnectSwiftV2.AnyCodable(nil as String?)

            default:
                throw WCError.unsupportedMethod(method)
            }

            try await Sign.instance.respond(
                topic: topic,
                requestId: request.id,
                response: .response(response)
            )

            print("[WC] Responded to \(method) successfully")

        } catch {
            print("[WC] Error handling \(method): \(error.localizedDescription)")

            let jsonRpcError = JSONRPCError(code: 4001, message: error.localizedDescription)
            try? await Sign.instance.respond(
                topic: topic,
                requestId: request.id,
                response: .error(jsonRpcError)
            )
        }
    }

    /// Handle eth_sendTransaction — parse tx params, sign via KeyringManager, broadcast via TransactionManager.
    private func handleSendTransaction(_ request: Request) async throws -> String {
        // Decode transaction parameters from the request
        let txParams = try request.params.get([EthSendTransactionParam].self)
        guard let param = txParams.first else {
            throw WCError.invalidParams
        }

        let from = param.from
        let to = param.to
        let value = param.value ?? "0x0"
        let data = param.data ?? "0x"

        // Determine chain from request chainId (CAIP-2: eip155:1 -> chainId 1)
        let chainIdInt = extractChainId(from: request.chainId.absoluteString) ?? 1
        let chain = chainManager.getChain(byId: chainIdInt) ?? Chain.ethereum

        // Build a complete transaction with proper nonce and gas estimation
        let txManager = TransactionManager.shared
        let nonce = try await txManager.getRecommendedNonce(address: from, chain: chain)

        let gasLimit: BigUInt
        if let gasHex = param.gas ?? param.gasLimit {
            gasLimit = BigUInt(gasHex.stripHexPrefix(), radix: 16) ?? BigUInt(21000)
        } else {
            gasLimit = try await txManager.estimateGas(from: from, to: to, value: value, data: data, chain: chain)
        }

        var transaction = EthereumTransaction(
            to: to,
            from: from,
            nonce: nonce,
            value: BigUInt(value.stripHexPrefix(), radix: 16) ?? BigUInt(0),
            data: Data(hexString: data) ?? Data(),
            gasLimit: gasLimit,
            chainId: chainIdInt
        )

        // Gas fees
        if let maxFee = param.maxFeePerGas, let maxPriority = param.maxPriorityFeePerGas {
            transaction.maxFeePerGas = BigUInt(maxFee.stripHexPrefix(), radix: 16)
            transaction.maxPriorityFeePerGas = BigUInt(maxPriority.stripHexPrefix(), radix: 16)
        } else if let gasPriceHex = param.gasPrice {
            transaction.gasPrice = BigUInt(gasPriceHex.stripHexPrefix(), radix: 16)
        } else if chain.supportsEIP1559 {
            if let feeData = try await txManager.getEIP1559FeeData(chain: chain) {
                transaction.maxFeePerGas = feeData.maxFeePerGas
                transaction.maxPriorityFeePerGas = feeData.maxPriorityFeePerGas
            }
        } else {
            transaction.gasPrice = try await txManager.getGasPrice(chain: chain)
        }

        // Sign and send
        let txHash = try await txManager.sendTransaction(transaction)

        print("[WC] Transaction sent: \(txHash)")
        return txHash
    }

    /// Handle personal_sign — params: [message, address]
    private func handlePersonalSign(_ request: Request) async throws -> String {
        let params = try request.params.get([String].self)
        guard params.count >= 2 else {
            throw WCError.invalidParams
        }

        let message = params[0]  // hex-encoded message
        let address = params[1]  // signer address

        guard let messageData = Data(hexString: message) else {
            throw WCError.invalidParams
        }

        let signature = try await keyringManager.signMessage(address: address, message: messageData)
        return "0x" + signature.hexString
    }

    /// Handle eth_signTypedData_v4 (and v3) — params: [address, typedDataJSON]
    private func handleSignTypedData(_ request: Request) async throws -> String {
        let params = try request.params.get([String].self)
        guard params.count >= 2 else {
            throw WCError.invalidParams
        }

        let address = params[0]
        let typedDataJSON = params[1]

        let signature = try await keyringManager.signTypedData(address: address, typedData: typedDataJSON)
        return "0x" + signature.hexString
    }

    /// Handle wallet_switchEthereumChain — params: [{ chainId: "0x1" }]
    private func handleSwitchEthereumChain(_ request: Request) async throws {
        let params = try request.params.get([SwitchChainParam].self)
        guard let param = params.first else {
            throw WCError.invalidParams
        }

        let chainIdHex = param.chainId
        guard let chainIdInt = Int(chainIdHex.stripHexPrefix(), radix: 16) else {
            throw WCError.invalidParams
        }

        guard let chain = chainManager.getChain(byId: chainIdInt) else {
            throw WCError.unsupportedChain(chainIdInt)
        }

        // Switch the selected chain in ChainManager
        chainManager.selectedChain = chain

        print("[WC] Switched chain to: \(chain.name) (id: \(chain.id))")

        // Notify the session about the chain change
        let topic = request.topic
        if Sign.instance.getSessions().first(where: { $0.topic == topic }) != nil {
            let chainChanged = Blockchain("eip155:\(chainIdInt)")!
            try? await Sign.instance.emit(
                topic: topic,
                event: Session.Event(name: "chainChanged", data: WalletConnectSwiftV2.AnyCodable(String(chainIdInt))),
                chainId: chainChanged
            )
        }
    }

    // MARK: - Session Management

    /// Disconnect a session by its ID (which is also the topic)
    func disconnectSession(_ sessionId: String) async {
        do {
            try await Sign.instance.disconnect(topic: sessionId)
            print("[WC] Disconnected session: \(sessionId)")
        } catch {
            print("[WC] Error disconnecting session: \(error.localizedDescription)")
        }
        removeSessionByTopic(sessionId)
    }

    /// Get active sessions for a specific address
    func getSessions(for address: String) -> [WCSession] {
        return sessions.filter { session in
            session.accounts.contains { $0.lowercased() == address.lowercased() }
        }
    }

    /// Get all active sessions from the WalletConnect SDK and sync with local state
    func refreshSessions() {
        let sdkSessions = Sign.instance.getSessions()

        // Remove local sessions that no longer exist in the SDK
        let activeTopics = Set(sdkSessions.map { $0.topic })
        sessions.removeAll { !activeTopics.contains($0.topic) }

        // Add any SDK sessions not yet tracked locally
        for sdkSession in sdkSessions {
            if !sessions.contains(where: { $0.topic == sdkSession.topic }) {
                didSettle(session: sdkSession)
            }
        }

        saveSessions()
    }

    /// Disconnect all active sessions
    func disconnectAllSessions() async {
        for session in sessions {
            try? await Sign.instance.disconnect(topic: session.topic)
        }
        sessions.removeAll()
        saveSessions()
        print("[WC] All sessions disconnected")
    }

    /// Remove expired sessions (older than maxDuration)
    func cleanupExpiredSessions() async {
        let now = Date()
        let expiredSessions = sessions.filter { now.timeIntervalSince($0.lastUsedAt) > maxDuration }

        for session in expiredSessions {
            try? await Sign.instance.disconnect(topic: session.topic)
        }

        sessions.removeAll { now.timeIntervalSince($0.lastUsedAt) > maxDuration }
        saveSessions()
    }

    // MARK: - Legacy Request Handling (for direct WCRequest usage)

    /// Approve pending request
    func approveRequest(_ requestId: String, result: Any) async throws {
        guard pendingRequests.first(where: { $0.id == requestId }) != nil else {
            throw WCError.requestNotFound
        }
        pendingRequests.removeAll { $0.id == requestId }
    }

    /// Reject pending request
    func rejectRequest(_ requestId: String, error: String) {
        pendingRequests.removeAll { $0.id == requestId }
    }

    /// Handle eth_sendTransaction request (legacy WCRequest interface)
    func handleSendTransaction(_ request: WCRequest) async throws -> String {
        guard let params = request.params as? [[String: Any]],
              let txParams = params.first else {
            throw WCError.invalidParams
        }

        guard let from = txParams["from"] as? String,
              let to = txParams["to"] as? String else {
            throw WCError.invalidParams
        }

        let value = txParams["value"] as? String ?? "0x0"
        let data = txParams["data"] as? String ?? "0x"
        let gas = txParams["gas"] as? String
        let gasPrice = txParams["gasPrice"] as? String

        let chainIdInt = Int(request.chainId) ?? 1
        let chain = chainManager.getChain(byId: chainIdInt) ?? Chain.ethereum
        let txManager = TransactionManager.shared

        let nonce = try await txManager.getRecommendedNonce(address: from, chain: chain)

        var transaction = EthereumTransaction(
            to: to,
            from: from,
            nonce: nonce,
            value: BigUInt(value.stripHexPrefix(), radix: 16) ?? BigUInt(0),
            data: Data(hexString: data) ?? Data(),
            gasLimit: BigUInt(gas?.stripHexPrefix() ?? "5208", radix: 16) ?? BigUInt(21000),
            chainId: chainIdInt
        )

        // Gas fees
        if let maxFeeHex = txParams["maxFeePerGas"] as? String,
           let maxPriorityHex = txParams["maxPriorityFeePerGas"] as? String {
            transaction.maxFeePerGas = BigUInt(maxFeeHex.stripHexPrefix(), radix: 16)
            transaction.maxPriorityFeePerGas = BigUInt(maxPriorityHex.stripHexPrefix(), radix: 16)
        } else if let gasPriceVal = gasPrice {
            transaction.gasPrice = BigUInt(gasPriceVal.stripHexPrefix(), radix: 16)
        } else if chain.supportsEIP1559 {
            if let feeData = try await txManager.getEIP1559FeeData(chain: chain) {
                transaction.maxFeePerGas = feeData.maxFeePerGas
                transaction.maxPriorityFeePerGas = feeData.maxPriorityFeePerGas
            }
        } else {
            transaction.gasPrice = try await txManager.getGasPrice(chain: chain)
        }

        let txHash = try await txManager.sendTransaction(transaction)
        return txHash
    }

    /// Handle personal_sign request (legacy WCRequest interface)
    func handlePersonalSign(_ request: WCRequest) async throws -> String {
        guard let params = request.params as? [String],
              params.count >= 2 else {
            throw WCError.invalidParams
        }

        let message = params[0]
        let address = params[1]

        guard let messageData = Data(hexString: message) else {
            throw WCError.invalidParams
        }

        let signature = try await keyringManager.signMessage(address: address, message: messageData)
        return "0x" + signature.hexString
    }

    /// Handle eth_signTypedData request (legacy WCRequest interface)
    func handleSignTypedData(_ request: WCRequest) async throws -> String {
        guard let params = request.params as? [Any],
              params.count >= 2 else {
            throw WCError.invalidParams
        }

        let address = params[0] as? String ?? ""

        let typedDataString: String
        if let typedData = params[1] as? [String: Any] {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: typedData),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw WCError.invalidParams
            }
            typedDataString = jsonString
        } else if let jsonString = params[1] as? String {
            typedDataString = jsonString
        } else {
            throw WCError.invalidParams
        }

        let signature = try await keyringManager.signTypedData(address: address, typedData: typedDataString)
        return "0x" + signature.hexString
    }

    // MARK: - Private Helpers

    private func removeSessionByTopic(_ topic: String) {
        sessions.removeAll { $0.topic == topic }
        saveSessions()

        NotificationCenter.default.post(
            name: .wcSessionDeleted,
            object: nil,
            userInfo: ["topic": topic]
        )
    }

    /// Extract numeric chain ID from a CAIP-2 string: "eip155:1" -> 1
    private func extractChainId(from caip2: String) -> Int? {
        let components = caip2.split(separator: ":")
        guard components.count == 2, let chainId = Int(components[1]) else {
            return nil
        }
        return chainId
    }

    private func loadSessions() {
        if let data = storage.getData(forKey: sessionsKey),
           let sessions = try? JSONDecoder().decode([WCSession].self, from: data) {
            self.sessions = sessions
        }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            storage.setData(data, forKey: sessionsKey)
        }
    }
}

// MARK: - WalletConnect JSON-RPC Parameter Types

/// Parameter model for eth_sendTransaction
private struct EthSendTransactionParam: Codable {
    let from: String
    let to: String
    let value: String?
    let data: String?
    let gas: String?
    let gasLimit: String?
    let gasPrice: String?
    let maxFeePerGas: String?
    let maxPriorityFeePerGas: String?
    let nonce: String?
}

/// Parameter model for wallet_switchEthereumChain
private struct SwitchChainParam: Codable {
    let chainId: String
}
// MARK: - String Hex Helper

private extension String {
    /// Remove "0x" prefix if present
    func stripHexPrefix() -> String {
        if hasPrefix("0x") || hasPrefix("0X") {
            return String(dropFirst(2))
        }
        return self
    }
}

// MARK: - Errors

enum WCError: Error, LocalizedError {
    case invalidURI
    case proposalNotFound
    case requestNotFound
    case invalidParams
    case notImplemented
    case connectionFailed
    case dangerousSignRejected
    case unsupportedMethod(String)
    case unsupportedChain(Int)
    case sessionNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURI:
            return "Invalid WalletConnect URI. Expected format: wc:<topic>@2?relay-protocol=irn&symKey=..."
        case .proposalNotFound:
            return "Session proposal not found"
        case .requestNotFound:
            return "Request not found"
        case .invalidParams:
            return "Invalid request parameters"
        case .notImplemented:
            return "WalletConnect SDK integration required. Please install WalletConnectSwiftV2 via CocoaPods."
        case .connectionFailed:
            return "Failed to connect to DApp via WalletConnect"
        case .dangerousSignRejected:
            return "eth_sign is disabled for security reasons. Use personal_sign or eth_signTypedData instead."
        case .unsupportedMethod(let method):
            return "Unsupported WalletConnect method: \(method)"
        case .unsupportedChain(let chainId):
            return "Unsupported chain ID: \(chainId)"
        case .sessionNotFound:
            return "WalletConnect session not found"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let wcSessionProposalReceived = Notification.Name("wcSessionProposalReceived")
    static let wcSessionSettled = Notification.Name("wcSessionSettled")
    static let wcSessionDeleted = Notification.Name("wcSessionDeleted")
    static let wcSessionRequestReceived = Notification.Name("wcSessionRequestReceived")
}
