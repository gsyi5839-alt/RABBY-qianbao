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
    @State private var pendingApprovalReply: ((Any?, String?, Int?) -> Void)?
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
                        onApprovalRequest: { request, reply in
                            pendingApproval = request
                            pendingApprovalReply = reply
                            showApproval = true
                        }
                    )
                }
                }
            }
            .navigationTitle(pageTitle.isEmpty ? LocalizationManager.shared.t("DApp Browser") : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showBookmarks = true }) {
                            Label(L("Bookmarks"), systemImage: "book")
                        }
                        if currentURL != nil {
                            Button(action: addBookmark) {
                                Label(L("Add Bookmark"), systemImage: "star")
                            }
                            Button(action: { currentURL = nil; urlString = "" }) {
                                Label(L("Home"), systemImage: "house")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showApproval) {
                if let approval = pendingApproval {
                    switch approval.type {
                    case .signTx:
                        TransactionApprovalView(
                            approval: approval,
                            onApprove: { txHash in pendingApprovalReply?(txHash, nil, nil) },
                            onReject: { pendingApprovalReply?(nil, "User rejected the request.", 4001) }
                        )
                    case .signText:
                        SignTextApprovalView(
                            text: approval.message ?? "",
                            origin: approval.origin,
                            signerAddress: approval.from,
                            siteName: approval.siteName,
                            onApprove: { approveSignText(approval) },
                            onReject: { pendingApprovalReply?(nil, "User rejected the request.", 4001) }
                        )
                    case .signTypedData:
                        SignTypedDataApprovalView(
                            typedDataJSON: approval.typedDataJSON ?? "",
                            origin: approval.origin,
                            signerAddress: approval.from,
                            siteName: approval.siteName,
                            onApprove: { approveSignTypedData(approval) },
                            onReject: { pendingApprovalReply?(nil, "User rejected the request.", 4001) }
                        )
                    case .connect:
                        DAppConnectSheet(
                            dappUrl: approval.origin ?? "unknown",
                            dappName: approval.siteName,
                            dappIcon: approval.iconUrl,
                            requestedPermissions: [],
                            onConnect: { selectedAddress in
                                pendingApprovalReply?([selectedAddress], nil, nil)
                            },
                            onReject: {
                                pendingApprovalReply?(nil, "User rejected the request.", 4001)
                            }
                        )
                    }
                }
            }
        }
    }

    private func approveSignText(_ approval: ApprovalRequest) {
        guard let from = approval.from as String?,
              let message = approval.message else {
            pendingApprovalReply?(nil, LocalizationManager.shared.t("Invalid params"), nil)
            return
        }

        let messageData: Data
        if message.hasPrefix("0x"), let hexData = Data(hexString: message) {
            messageData = hexData
        } else {
            messageData = message.data(using: .utf8) ?? Data()
        }

        Task {
            do {
                let sig = try await keyringManager.signMessage(address: from, message: messageData)
                let sigHex = "0x" + sig.toHexString()

                // Record to sign history
                let chainIdStr = "0x\(String(approval.chainId, radix: 16))"
                SignHistoryManager.shared.addSignHistory(
                    type: .personalSign,
                    address: from,
                    chainId: chainIdStr,
                    message: message,
                    signature: sigHex,
                    status: .signed,
                    dappName: approval.siteName ?? approval.origin,
                    dappOrigin: approval.origin
                )

                pendingApprovalReply?(sigHex, nil, nil)
            } catch {
                pendingApprovalReply?(nil, error.localizedDescription, nil)
            }
        }
    }
    
    private func approveSignTypedData(_ approval: ApprovalRequest) {
        guard let from = approval.from as String?,
              let typedData = approval.typedDataJSON else {
            pendingApprovalReply?(nil, LocalizationManager.shared.t("Invalid params"), nil)
            return
        }

        // Determine the sign history type from the original RPC method
        let historyType: SignHistoryManager.SignType
        switch approval.signMethod {
        case "eth_signTypedData_v3":
            historyType = .signTypedDataV3
        case "eth_signTypedData_v4":
            historyType = .signTypedDataV4
        default:
            historyType = .signTypedData
        }

        Task {
            do {
                let sig = try await keyringManager.signTypedData(address: from, typedData: typedData)
                let sigHex = "0x" + sig.toHexString()

                // Record to sign history
                let chainIdStr = "0x\(String(approval.chainId, radix: 16))"
                SignHistoryManager.shared.addSignHistory(
                    type: historyType,
                    address: from,
                    chainId: chainIdStr,
                    message: typedData,
                    signature: sigHex,
                    status: .signed,
                    dappName: approval.siteName ?? approval.origin,
                    dappOrigin: approval.origin
                )

                pendingApprovalReply?(sigHex, nil, nil)
            } catch {
                pendingApprovalReply?(nil, error.localizedDescription, nil)
            }
        }
    }
    
    private var urlBar: some View {
        HStack(spacing: 8) {
            if isLoading { ProgressView().scaleEffect(0.7) }
            
            TextField(L("Enter DApp URL or search"), text: $urlString)
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
                    Text(L("Explore DApps"))
                        .font(.title2).fontWeight(.bold)
                    Text(L("Browse decentralized applications safely"))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                
                // Popular DApps grid
                Text(L("Popular DApps")).font(.headline).padding(.horizontal)
                
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
                    Text(L("Recent Connections")).font(.headline).padding(.horizontal)
                    
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
    var onApprovalRequest: ((ApprovalRequest, @escaping (Any?, String?, Int?) -> Void) -> Void)?
    
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
            
            // Provider JS uses per-request callback ids. We must reply with the same id.
            let callbackId = body["id"] as? String
            
            switch method {
            case "eth_requestAccounts", "eth_accounts":
                // Return current account
                if let account = KeyringManager.shared.currentAccount {
                    respondToJS(message.webView, id: callbackId, result: [account.address])
                }
            case "eth_sendTransaction":
                handleSendTransaction(body, callbackId: callbackId, webView: message.webView)
            case "personal_sign", "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
                handleSignMessage(body, method: method, callbackId: callbackId, webView: message.webView)
            case "eth_chainId":
                if let chain = ChainManager.shared.selectedChain {
                    respondToJS(message.webView, id: callbackId, result: "0x\(String(chain.id, radix: 16))")
                }
            case "wallet_switchEthereumChain":
                handleSwitchChain(body, callbackId: callbackId, webView: message.webView)
            default:
                break
            }
        }
        
        private func handleSendTransaction(_ body: [String: Any], callbackId: String?, webView: WKWebView?) {
            guard let params = body["params"] as? [[String: Any]], let tx = params.first else { return }
            let request = ApprovalRequest(
                id: callbackId ?? UUID().uuidString,
                from: tx["from"] as? String ?? "",
                to: tx["to"] as? String,
                value: tx["value"] as? String,
                data: tx["data"] as? String,
                message: nil,
                typedDataJSON: nil,
                signMethod: "eth_sendTransaction",
                chainId: ChainManager.shared.selectedChain?.id ?? 1,
                origin: webView?.url?.host,
                siteName: nil, iconUrl: nil,
                isEIP1559: ChainManager.shared.selectedChain?.isEIP1559 ?? false,
                type: .signTx
            )

            let reply: (Any?, String?, Int?) -> Void = { [weak webView] result, error, errorCode in
                Task { @MainActor in
                    if let error = error {
                        self.respondToJS(webView, id: callbackId, result: NSNull(), error: error, errorCode: errorCode)
                    } else {
                        self.respondToJS(webView, id: callbackId, result: result ?? NSNull())
                    }
                }
            }
            
            Task { @MainActor in parent.onApprovalRequest?(request, reply) }
        }
        
        private func handleSignMessage(_ body: [String: Any], method: String, callbackId: String?, webView: WKWebView?) {
            guard let params = body["params"] as? [Any], params.count >= 2 else { return }
            
            func isAddress(_ value: Any) -> Bool {
                guard let s = value as? String else { return false }
                return EthereumUtil.isValidAddress(s)
            }
            
            let request: ApprovalRequest
            switch method {
            case "personal_sign":
                // Metamask: personal_sign(message, address) but some dapps swap order.
                var messageParam = params[0]
                var addressParam = params[1]
                if isAddress(messageParam) && !isAddress(addressParam) {
                    swap(&messageParam, &addressParam)
                }
                guard let address = addressParam as? String else { return }
                let message = messageParam as? String ?? ""
                
                request = ApprovalRequest(
                    id: callbackId ?? UUID().uuidString,
                    from: address,
                    to: nil,
                    value: nil,
                    data: nil,
                    message: message,
                    typedDataJSON: nil,
                    signMethod: method,
                    chainId: ChainManager.shared.selectedChain?.id ?? 1,
                    origin: webView?.url?.host,
                    siteName: nil,
                    iconUrl: nil,
                    isEIP1559: ChainManager.shared.selectedChain?.isEIP1559 ?? false,
                    type: .signText
                )
                
            case "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
                // Metamask: eth_signTypedData[_v3|_v4](address, typedDataJSON)
                guard let address = params[0] as? String else { return }

                let typedDataJSON: String
                if let jsonString = params[1] as? String {
                    typedDataJSON = jsonString
                } else {
                    let obj = params[1]
                    guard JSONSerialization.isValidJSONObject(obj),
                          let data = try? JSONSerialization.data(withJSONObject: obj),
                          let jsonString = String(data: data, encoding: .utf8) else { return }
                    typedDataJSON = jsonString
                }

                request = ApprovalRequest(
                    id: callbackId ?? UUID().uuidString,
                    from: address,
                    to: nil,
                    value: nil,
                    data: nil,
                    message: nil,
                    typedDataJSON: typedDataJSON,
                    signMethod: method,
                    chainId: ChainManager.shared.selectedChain?.id ?? 1,
                    origin: webView?.url?.host,
                    siteName: nil,
                    iconUrl: nil,
                    isEIP1559: ChainManager.shared.selectedChain?.isEIP1559 ?? false,
                    type: .signTypedData
                )
                
            default:
                return
            }
            
            let reply: (Any?, String?, Int?) -> Void = { [weak webView] result, error, errorCode in
                Task { @MainActor in
                    if let error = error {
                        self.respondToJS(webView, id: callbackId, result: NSNull(), error: error, errorCode: errorCode)
                    } else {
                        self.respondToJS(webView, id: callbackId, result: result ?? NSNull())
                    }
                }
            }

            Task { @MainActor in parent.onApprovalRequest?(request, reply) }
        }
        
        private func handleSwitchChain(_ body: [String: Any], callbackId: String?, webView: WKWebView?) {
            guard let params = body["params"] as? [[String: Any]],
                  let chainIdHex = params.first?["chainId"] as? String,
                  let chainId = UInt64(chainIdHex.dropFirst(2), radix: 16),
                  let chain = ChainManager.shared.getChain(id: Int(chainId)) else { return }
            Task { @MainActor in ChainManager.shared.selectChain(chain) }
            respondToJS(webView, id: callbackId, result: NSNull())
        }
        
        private func respondToJS(_ webView: WKWebView?, id: String?, result: Any, error: String? = nil, errorCode: Int? = nil) {
            guard let webView = webView, let callbackId = id else { return }
            let resultJSON: String
            if let error = error {
                let escapedError = error.replacingOccurrences(of: "'", with: "\\'")
                let code = errorCode ?? -1
                let js = "window.ethereum._resolveCallback('\(callbackId)', null, '\(escapedError)', \(code))"
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
            let js = "window.ethereum._resolveCallback('\(callbackId)', \(resultJSON), null, null)"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    /// Injected Ethereum provider JavaScript - uses per-request callbacks to handle concurrency
    private var ethereumProviderJS: String {
        """
        (function() {
            var _callbacks = {};
            var _nextId = 1;
            var _eventListeners = {};
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
                _resolveCallback: function(callbackId, result, error, code) {
                    var cb = _callbacks[callbackId];
                    if (cb) {
                        if (error) {
                            var err = new Error(error);
                            err.code = code || -1;
                            cb.reject(err);
                        }
                        else { cb.resolve(result); }
                        delete _callbacks[callbackId];
                    }
                },
                on: function(event, handler) {
                    if (!_eventListeners[event]) { _eventListeners[event] = []; }
                    _eventListeners[event].push(handler);
                    return this;
                },
                removeListener: function(event, handler) {
                    var listeners = _eventListeners[event];
                    if (listeners) {
                        _eventListeners[event] = listeners.filter(function(h) { return h !== handler; });
                    }
                    return this;
                },
                emit: function(event) {
                    var args = Array.prototype.slice.call(arguments, 1);
                    var listeners = _eventListeners[event] || [];
                    listeners.forEach(function(h) { try { h.apply(null, args); } catch(e) {} });
                },
                enable: function() { return this.request({ method: 'eth_requestAccounts' }); },
                sendAsync: function(payload, callback) {
                    var method = payload.method;
                    var params = payload.params || [];
                    this.request({ method: method, params: params }).then(
                        function(result) { callback(null, { id: payload.id, jsonrpc: '2.0', result: result }); },
                        function(error) { callback(error, null); }
                    );
                },
                send: function(methodOrPayload, paramsOrCallback) {
                    if (typeof methodOrPayload === 'string') {
                        return this.request({ method: methodOrPayload, params: paramsOrCallback || [] });
                    }
                    if (typeof paramsOrCallback === 'function') {
                        return this.sendAsync(methodOrPayload, paramsOrCallback);
                    }
                    return this.request({ method: methodOrPayload.method, params: methodOrPayload.params || [] });
                },
            };
            window.dispatchEvent(new Event('ethereum#initialized'));
        })();
        """
    }
}
