import Foundation
import os.log

// MARK: - Deep Link Route

/// Defines all supported deep link destinations within the Rabby Wallet app.
/// Each case carries the parsed parameters extracted from the incoming URL.
enum DeepLinkRoute: Equatable {
    /// WalletConnect pairing via `wc:` URI or `?uri=` parameter
    case walletConnect(uri: String)

    /// Open send-token page, optionally pre-filled with recipient, amount, chain, and token
    case send(to: String?, amount: String?, chainId: String?, token: String?)

    /// Open swap page, optionally pre-filled with from/to tokens and chain
    case swap(fromToken: String?, toToken: String?, chainId: String?)

    /// Open bridge page, optionally pre-filled with source and destination chains
    case bridge(fromChain: String?, toChain: String?)

    /// Open the DApp browser and navigate to the given URL
    case dapp(url: String)

    /// Open the receive / deposit screen
    case receive

    /// Open the settings screen
    case settings
}

// MARK: - DeepLinkRouter

/// Central router that receives incoming URLs (custom-scheme, Universal Links, QR-scan
/// results) and converts them into `DeepLinkRoute` values that the UI layer observes.
///
/// Integration in SwiftUI views:
/// ```
/// // In MainTabView or any root-level container:
/// .onChange(of: DeepLinkRouter.shared.pendingRoute) { route in
///     guard let route = route else { return }
///     switch route {
///     case .walletConnect(let uri):
///         // Trigger WalletConnect pairing flow
///     case .send(let to, let amount, let chainId, let token):
///         // Navigate to Send page with pre-filled parameters
///     case .swap(let fromToken, let toToken, let chainId):
///         // Navigate to Swap page
///     case .bridge(let fromChain, let toChain):
///         // Navigate to Bridge page
///     case .dapp(let url):
///         // Open DApp browser with url
///     case .receive:
///         // Navigate to Receive page
///     case .settings:
///         // Navigate to Settings page
///     }
///     DeepLinkRouter.shared.clearRoute()
/// }
/// ```
@MainActor
final class DeepLinkRouter: ObservableObject {

    // MARK: - Singleton

    static let shared = DeepLinkRouter()

    // MARK: - Published state

    /// The most recently parsed route awaiting consumption by the UI layer.
    /// Views should observe this property and clear it after handling via `clearRoute()`.
    @Published var pendingRoute: DeepLinkRoute?

    // MARK: - Constants

    /// The host used for Universal Links (e.g. https://rabby.io/...)
    private static let universalLinkHost = "rabby.io"

    /// Supported custom URL schemes
    private static let customScheme = "rabbywallet"
    private static let wcScheme = "wc"

    private let logger = Logger(subsystem: "com.bocail.pay", category: "DeepLinkRouter")

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Main entry point: attempts to handle any URL regardless of its origin.
    /// Returns `true` if the URL was recognized and routed, `false` otherwise.
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        logger.info("DeepLinkRouter received URL: \(url.absoluteString, privacy: .public)")

        // 1. WalletConnect direct URI (wc:topic@2?...)
        if url.scheme == Self.wcScheme {
            return handleWalletConnectDirectURI(url)
        }

        // 2. Custom scheme: rabbywallet://...
        if url.scheme == Self.customScheme {
            return handleCustomScheme(url)
        }

        // 3. Universal Link: https://rabby.io/...
        if isUniversalLink(url) {
            return handleUniversalLink(url)
        }

        logger.warning("Unrecognized URL scheme: \(url.scheme ?? "nil", privacy: .public)")
        return false
    }

    /// Handles Universal Links specifically (called from `onContinueUserActivity`).
    /// Returns `true` if the URL was recognized and routed.
    @discardableResult
    func handleUniversalLink(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.warning("Failed to parse Universal Link components: \(url.absoluteString, privacy: .public)")
            return false
        }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let params = queryDictionary(from: components)

        logger.info("Universal Link path: \(path, privacy: .public)")

        switch path {
        case "wc":
            // https://rabby.io/wc?uri=wc:topic@2?relay-protocol=...&symKey=...
            if let uri = params["uri"], !uri.isEmpty {
                pendingRoute = .walletConnect(uri: uri)
                return true
            }
            logger.warning("Universal Link /wc missing 'uri' parameter")
            return false

        case "send":
            // https://rabby.io/send?to=0x...&amount=1.0&chain=1&token=ETH
            pendingRoute = .send(
                to: params["to"],
                amount: params["amount"],
                chainId: params["chain"],
                token: params["token"]
            )
            return true

        case "swap":
            // https://rabby.io/swap?from=ETH&to=USDC&chain=1
            pendingRoute = .swap(
                fromToken: params["from"],
                toToken: params["to"],
                chainId: params["chain"]
            )
            return true

        case "bridge":
            // https://rabby.io/bridge?from=1&to=137
            pendingRoute = .bridge(
                fromChain: params["from"],
                toChain: params["to"]
            )
            return true

        case "dapp":
            // https://rabby.io/dapp?url=https://app.uniswap.org
            if let dappURL = params["url"], !dappURL.isEmpty {
                pendingRoute = .dapp(url: dappURL)
                return true
            }
            logger.warning("Universal Link /dapp missing 'url' parameter")
            return false

        case "receive":
            pendingRoute = .receive
            return true

        case "settings":
            pendingRoute = .settings
            return true

        default:
            logger.warning("Universal Link unrecognized path: \(path, privacy: .public)")
            return false
        }
    }

    /// Handles QR code scan results. The scanned string might be a WalletConnect URI,
    /// an Ethereum address, or a full deep link URL.
    @discardableResult
    func handleQRScanResult(_ scannedString: String) -> Bool {
        logger.info("QR scan result: \(scannedString.prefix(80), privacy: .public)")

        // WalletConnect URI: starts with "wc:"
        if scannedString.hasPrefix("wc:") {
            pendingRoute = .walletConnect(uri: scannedString)
            return true
        }

        // Ethereum address: 0x followed by 40 hex characters
        if scannedString.hasPrefix("0x"), scannedString.count == 42 {
            pendingRoute = .send(to: scannedString, amount: nil, chainId: nil, token: nil)
            return true
        }

        // EIP-681 ethereum: URI (ethereum:0x...@chainId/transfer?...)
        if scannedString.hasPrefix("ethereum:") {
            return handleEIP681URI(scannedString)
        }

        // Try parsing as a generic URL
        if let url = URL(string: scannedString) {
            return handleURL(url)
        }

        logger.warning("QR scan result not recognized")
        return false
    }

    /// Clears the pending route after the UI has consumed it.
    func clearRoute() {
        pendingRoute = nil
    }

    // MARK: - Private: WalletConnect Direct

    private func handleWalletConnectDirectURI(_ url: URL) -> Bool {
        let wcURI = url.absoluteString
        guard !wcURI.isEmpty else { return false }
        pendingRoute = .walletConnect(uri: wcURI)
        return true
    }

    // MARK: - Private: Custom Scheme (rabbywallet://)

    private func handleCustomScheme(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        let host = components.host ?? ""
        let params = queryDictionary(from: components)

        switch host {
        case "wc":
            // rabbywallet://wc?uri=wc:topic@2?...
            if let uri = params["uri"], !uri.isEmpty {
                pendingRoute = .walletConnect(uri: uri)
                return true
            }
            return false

        case "send":
            // rabbywallet://send?to=0x...&amount=1.0&chain=1&token=ETH
            pendingRoute = .send(
                to: params["to"],
                amount: params["amount"],
                chainId: params["chain"],
                token: params["token"]
            )
            return true

        case "swap":
            // rabbywallet://swap?from=ETH&to=USDC&chain=1
            pendingRoute = .swap(
                fromToken: params["from"],
                toToken: params["to"],
                chainId: params["chain"]
            )
            return true

        case "bridge":
            // rabbywallet://bridge?from=1&to=137
            pendingRoute = .bridge(
                fromChain: params["from"],
                toChain: params["to"]
            )
            return true

        case "dapp":
            // rabbywallet://dapp?url=https://app.uniswap.org
            if let dappURL = params["url"], !dappURL.isEmpty {
                pendingRoute = .dapp(url: dappURL)
                return true
            }
            return false

        case "receive":
            pendingRoute = .receive
            return true

        case "settings":
            pendingRoute = .settings
            return true

        default:
            logger.warning("Custom scheme unrecognized host: \(host, privacy: .public)")
            return false
        }
    }

    // MARK: - Private: EIP-681

    /// Parses a minimal EIP-681 ethereum: URI into a send route.
    /// Format: ethereum:<address>[@<chainId>][/transfer?...]
    private func handleEIP681URI(_ uriString: String) -> Bool {
        // Strip "ethereum:" prefix
        let body = String(uriString.dropFirst("ethereum:".count))

        // Split on optional "@" for chain ID
        var address: String
        var chainId: String?

        if let atIndex = body.firstIndex(of: "@") {
            address = String(body[body.startIndex..<atIndex])
            let rest = String(body[body.index(after: atIndex)...])
            // Chain ID ends at "/" or end of string
            if let slashIndex = rest.firstIndex(of: "/") {
                chainId = String(rest[rest.startIndex..<slashIndex])
            } else {
                chainId = rest
            }
        } else if let slashIndex = body.firstIndex(of: "/") {
            address = String(body[body.startIndex..<slashIndex])
        } else {
            address = body
        }

        // Clean up address (remove query params if any)
        if let queryIndex = address.firstIndex(of: "?") {
            address = String(address[address.startIndex..<queryIndex])
        }

        guard address.hasPrefix("0x"), address.count == 42 else {
            logger.warning("EIP-681 invalid address: \(address, privacy: .public)")
            return false
        }

        pendingRoute = .send(to: address, amount: nil, chainId: chainId, token: nil)
        return true
    }

    // MARK: - Private: Helpers

    private func isUniversalLink(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return (url.scheme == "https" || url.scheme == "http") && host == Self.universalLinkHost
    }

    private func queryDictionary(from components: URLComponents) -> [String: String] {
        guard let items = components.queryItems else { return [:] }
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
    }
}
