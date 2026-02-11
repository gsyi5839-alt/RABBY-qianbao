import SwiftUI
import WebKit

/// DApp Browser - In-app Web3 DApp browser with injected provider
/// Corresponds to: src/ui/views/DappSearch/ + src/ui/views/Ecology/
struct DAppBrowserView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var permManager = DAppPermissionManager.shared
    @State private var urlString = ""
    @State private var isLoading = false
    @State private var currentURL: URL?
    @State private var pageTitle: String = ""
    @State private var showBookmarks = false
    @State private var showApproval = false
    @State private var pendingApproval: ApprovalRequest?
    @State private var bookmarks: [DAppBookmark] = []
    
    struct DAppBookmark: Identifiable, Codable {
        let id: String
        let name: String
        let url: String
        let icon: String?
    }
    
    // Popular DApps
    let popularDApps: [DAppBookmark] = [
        DAppBookmark(id: "uniswap", name: "Uniswap", url: "https://app.uniswap.org", icon: nil),
        DAppBookmark(id: "aave", name: "Aave", url: "https://app.aave.com", icon: nil),
        DAppBookmark(id: "opensea", name: "OpenSea", url: "https://opensea.io", icon: nil),
        DAppBookmark(id: "curve", name: "Curve", url: "https://curve.fi", icon: nil),
        DAppBookmark(id: "1inch", name: "1inch", url: "https://app.1inch.io", icon: nil),
        DAppBookmark(id: "lido", name: "Lido", url: "https://stake.lido.fi", icon: nil),
        DAppBookmark(id: "compound", name: "Compound", url: "https://app.compound.finance", icon: nil),
        DAppBookmark(id: "pancakeswap", name: "PancakeSwap", url: "https://pancakeswap.finance", icon: nil),
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // URL bar
                urlBar
                
                if currentURL == nil {
                    // Homepage with popular DApps
                    homePage
                } else {
                if let url = currentURL {
                    // Web view
                    DAppWebView(
                        url: url,
                        isLoading: $isLoading,
                        pageTitle: $pageTitle,
                        onApprovalRequest: { request in
                            pendingApproval = request
                            showApproval = true
                        }
                    )
                }
                }
            }
            .navigationTitle(pageTitle.isEmpty ? "DApp Browser" : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showBookmarks = true }) {
                            Label("Bookmarks", systemImage: "book")
                        }
                        if currentURL != nil {
                            Button(action: addBookmark) {
                                Label("Add Bookmark", systemImage: "star")
                            }
                            Button(action: { currentURL = nil; urlString = "" }) {
                                Label("Home", systemImage: "house")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showApproval) {
                if let approval = pendingApproval {
                    TransactionApprovalView(approval: approval)
                }
            }
        }
    }
    
    private var urlBar: some View {
        HStack(spacing: 8) {
            if isLoading { ProgressView().scaleEffect(0.7) }
            
            TextField("Enter DApp URL or search", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)
                .onSubmit { navigateToURL() }
            
            Button(action: navigateToURL) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var homePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Search bar hero
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    Text("Explore DApps")
                        .font(.title2).fontWeight(.bold)
                    Text("Browse decentralized applications safely")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                
                // Popular DApps grid
                Text("Popular DApps").font(.headline).padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(popularDApps) { dapp in
                        Button(action: { navigateTo(dapp.url) }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Text(String(dapp.name.prefix(1)))
                                            .font(.title3).fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    )
                                Text(dapp.name)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Recent connections
                if !permManager.connectedSites.isEmpty {
                    Text("Recent Connections").font(.headline).padding(.horizontal)
                    
                    ForEach(permManager.connectedSites.prefix(5)) { site in
                        Button(action: { navigateTo(site.origin) }) {
                            HStack {
                                Circle().fill(Color.green.opacity(0.2)).frame(width: 32, height: 32)
                                    .overlay(Text(String(site.name.prefix(1))).font(.caption).foregroundColor(.green))
                                VStack(alignment: .leading) {
                                    Text(site.name).font(.subheadline).foregroundColor(.primary)
                                    Text(site.origin).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 30)
        }
    }
    
    private func navigateToURL() {
        var url = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            if url.contains(".") { url = "https://\(url)" }
            else { url = "https://www.google.com/search?q=\(url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url)" }
        }
        if let parsedURL = URL(string: url) {
            currentURL = parsedURL
            urlString = url
        }
    }
    
    private func navigateTo(_ urlStr: String) {
        urlString = urlStr
        navigateToURL()
    }
    
    private func addBookmark() {
        guard let url = currentURL else { return }
        let bookmark = DAppBookmark(id: UUID().uuidString, name: pageTitle.isEmpty ? url.host ?? "Unknown" : pageTitle, url: url.absoluteString, icon: nil)
        bookmarks.append(bookmark)
    }
}

/// WKWebView wrapper for DApp interaction
struct DAppWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    var onApprovalRequest: ((ApprovalRequest) -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Inject Ethereum provider
        let providerScript = WKUserScript(
            source: ethereumProviderJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(providerScript)
        config.userContentController.add(context.coordinator, name: "rabbyProvider")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: DAppWebView
        
        init(_ parent: DAppWebView) { self.parent = parent }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in parent.isLoading = true }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                parent.isLoading = false
                parent.pageTitle = webView.title ?? ""
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "rabbyProvider",
                  let body = message.body as? [String: Any],
                  let method = body["method"] as? String else { return }
            
            switch method {
            case "eth_requestAccounts", "eth_accounts":
                // Return current account
                if let account = KeyringManager.shared.currentAccount {
                    respondToJS(message.webView, id: body["id"], result: [account.address])
                }
            case "eth_sendTransaction":
                handleSendTransaction(body, webView: message.webView)
            case "personal_sign", "eth_signTypedData_v4":
                handleSignMessage(body, method: method, webView: message.webView)
            case "eth_chainId":
                if let chain = ChainManager.shared.selectedChain {
                    respondToJS(message.webView, id: body["id"], result: "0x\(String(chain.id, radix: 16))")
                }
            case "wallet_switchEthereumChain":
                handleSwitchChain(body, webView: message.webView)
            default:
                break
            }
        }
        
        private func handleSendTransaction(_ body: [String: Any], webView: WKWebView?) {
            guard let params = body["params"] as? [[String: Any]], let tx = params.first else { return }
            let request = ApprovalRequest(
                id: UUID().uuidString,
                from: tx["from"] as? String ?? "",
                to: tx["to"] as? String,
                value: tx["value"] as? String,
                data: tx["data"] as? String,
                chainId: ChainManager.shared.selectedChain?.id ?? 1,
                origin: webView?.url?.host,
                siteName: nil, iconUrl: nil,
                isEIP1559: ChainManager.shared.selectedChain?.isEIP1559 ?? false,
                type: .signTx
            )
            Task { @MainActor in parent.onApprovalRequest?(request) }
        }
        
        private func handleSignMessage(_ body: [String: Any], method: String, webView: WKWebView?) {
            // Sign message request handling
        }
        
        private func handleSwitchChain(_ body: [String: Any], webView: WKWebView?) {
            guard let params = body["params"] as? [[String: Any]],
                  let chainIdHex = params.first?["chainId"] as? String,
                  let chainId = UInt64(chainIdHex.dropFirst(2), radix: 16),
                  let chain = ChainManager.shared.getChain(id: Int(chainId)) else { return }
            Task { @MainActor in ChainManager.shared.selectChain(chain) }
            respondToJS(webView, id: body["id"], result: NSNull())
        }
        
        private func respondToJS(_ webView: WKWebView?, id: Any?, result: Any, error: String? = nil) {
            guard let webView = webView, let callbackId = id as? String else { return }
            let resultJSON: String
            if let error = error {
                let escapedError = error.replacingOccurrences(of: "'", with: "\\'")
                let js = "window.ethereum._resolveCallback('\(callbackId)', null, '\(escapedError)')"
                webView.evaluateJavaScript(js, completionHandler: nil)
                return
            }
            if let data = try? JSONSerialization.data(withJSONObject: result), let str = String(data: data, encoding: .utf8) {
                resultJSON = str
            } else if result is NSNull {
                resultJSON = "null"
            } else {
                resultJSON = "\"\(result)\""
            }
            let js = "window.ethereum._resolveCallback('\(callbackId)', \(resultJSON), null)"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    /// Injected Ethereum provider JavaScript - uses per-request callbacks to handle concurrency
    private var ethereumProviderJS: String {
        """
        (function() {
            var _callbacks = {};
            var _nextId = 1;
            window.ethereum = {
                isRabby: true,
                isMetaMask: true,
                chainId: '0x1',
                selectedAddress: null,
                request: function(args) {
                    return new Promise(function(resolve, reject) {
                        var callbackId = 'cb_' + (_nextId++);
                        _callbacks[callbackId] = { resolve: resolve, reject: reject };
                        window.webkit.messageHandlers.rabbyProvider.postMessage({
                            method: args.method,
                            params: args.params || [],
                            id: callbackId
                        });
                    });
                },
                _resolveCallback: function(callbackId, result, error) {
                    var cb = _callbacks[callbackId];
                    if (cb) {
                        if (error) { cb.reject(new Error(error)); }
                        else { cb.resolve(result); }
                        delete _callbacks[callbackId];
                    }
                },
                on: function(event, handler) { },
                removeListener: function(event, handler) { },
                enable: function() { return this.request({ method: 'eth_requestAccounts' }); },
            };
            window.dispatchEvent(new Event('ethereum#initialized'));
        })();
        """
    }
}
