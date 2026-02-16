import SwiftUI
import WebKit
import Combine

/// DApp Browser - In-app Web3 DApp browser with injected provider
/// Corresponds to: src/ui/views/DappSearch/ + src/ui/views/Ecology/
struct DAppBrowserView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var permManager = DAppPermissionManager.shared
    @StateObject private var bookmarkManager = DAppBookmarkManager.shared
    @State private var urlString = ""
    @State private var isLoading = false
    @State private var currentURL: URL?
    @State private var pageTitle: String = ""
    @State private var showBookmarks = false
    @State private var showSiteInfo = false
    @State private var showApproval = false
    @State private var pendingApproval: ApprovalRequest?
    @State private var pendingApprovalReply: ((Any?, String?, Int?) -> Void)?
    @StateObject private var browserNavigation = DAppBrowserNavigationState()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // URL bar
                urlBar
                
                if currentURL == nil {
                    homePage
                } else if let url = currentURL {
                    siteHeaderBar
                    DAppWebView(
                        url: url,
                        isLoading: $isLoading,
                        pageTitle: $pageTitle,
                        onApprovalRequest: { request, reply in
                            pendingApproval = request
                            pendingApprovalReply = reply
                            showApproval = true
                        },
                        onPageVisited: { visitedURL, title, iconURL in
                            let pageName = title.isEmpty ? (visitedURL.host ?? "Unknown") : title
                            let resolvedIcon = (iconURL?.isEmpty == false ? iconURL! : DAppBookmarkManager.faviconURL(for: visitedURL.absoluteString))
                            DispatchQueue.main.async {
                                bookmarkManager.addToRecent(
                                    url: visitedURL.absoluteString,
                                    title: pageName,
                                    iconURL: resolvedIcon
                                )
                            }
                        },
                        onURLChange: { newURL in
                            guard let newURL else { return }
                            currentURL = newURL
                            urlString = newURL.absoluteString
                        },
                        navigationState: browserNavigation
                    )
                    browserActionBar
                }
            }
            .navigationTitle(pageTitle.isEmpty ? LocalizationManager.shared.t("DApp Browser") : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentURL != nil {
                        Button(action: exitToHome) {
                            Label(L("DApps Home"), systemImage: "house")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showBookmarks = true }) {
                            Label(L("Bookmarks"), systemImage: "book")
                        }
                        if currentURL != nil {
                            Button(action: addBookmark) {
                                Label(L("Add Bookmark"), systemImage: "star")
                            }
                            Button(action: { showSiteInfo = true }) {
                                Label(L("Site Info"), systemImage: "info.circle")
                            }
                            Button(action: exitToHome) {
                                Label(L("Exit Website"), systemImage: "xmark.circle")
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
                        MessageApprovalView(
                            message: approval.message ?? "",
                            fromAddress: approval.from,
                            origin: approval.origin,
                            onApprove: { signature in
                                pendingApprovalReply?(signature, nil, nil)
                            },
                            onReject: {
                                pendingApprovalReply?(nil, "User rejected the request.", 4001)
                            }
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
            .sheet(isPresented: $showBookmarks) {
                NavigationView {
                    List {
                        if bookmarkManager.bookmarks.isEmpty {
                            Text(L("No bookmarks yet"))
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(bookmarkManager.bookmarks) { bookmark in
                                Button(action: {
                                    showBookmarks = false
                                    navigateTo(bookmark.url)
                                }) {
                                    HStack(spacing: 12) {
                                        dappIcon(title: bookmark.title, iconURL: bookmark.iconURL, size: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(bookmark.title)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text(bookmark.url)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .onDelete(perform: removeBookmarks)
                        }
                    }
                    .navigationTitle(L("Bookmarks"))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(L("Done")) { showBookmarks = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showSiteInfo) {
                siteInfoSheet
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

    private var siteHeaderBar: some View {
        let pageURL = browserNavigation.currentURL ?? currentURL
        let host = pageURL?.host ?? "Unknown site"

        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(host)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(pageURL?.absoluteString ?? "")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: { showSiteInfo = true }) {
                Label(L("Info"), systemImage: "info.circle")
            }
            .font(.caption)

            Button(action: exitToHome) {
                Label(L("Exit"), systemImage: "xmark.circle")
            }
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private var browserActionBar: some View {
        HStack(spacing: 22) {
            actionBarButton(
                title: LocalizationManager.shared.t("Back", defaultValue: "Back"),
                systemImage: "chevron.left",
                disabled: !browserNavigation.canGoBack
            ) {
                browserNavigation.goBack()
            }

            actionBarButton(
                title: LocalizationManager.shared.t("Forward", defaultValue: "Forward"),
                systemImage: "chevron.right",
                disabled: !browserNavigation.canGoForward
            ) {
                browserNavigation.goForward()
            }

            actionBarButton(
                title: LocalizationManager.shared.t("Reload", defaultValue: "Reload"),
                systemImage: "arrow.clockwise"
            ) {
                browserNavigation.reload()
            }

            actionBarButton(
                title: LocalizationManager.shared.t("Info", defaultValue: "Info"),
                systemImage: "info.circle"
            ) {
                showSiteInfo = true
            }

            actionBarButton(
                title: LocalizationManager.shared.t("Exit", defaultValue: "Exit"),
                systemImage: "xmark.circle"
            ) {
                exitToHome()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private func actionBarButton(
        title: String,
        systemImage: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                Text(title)
                    .font(.caption2)
            }
            .frame(minWidth: 44)
        }
        .foregroundColor(disabled ? .gray : .primary)
        .disabled(disabled)
    }

    private var siteInfoSheet: some View {
        let pageURL = browserNavigation.currentURL ?? currentURL
        let host = pageURL?.host?.lowercased() ?? ""
        let site = permManager.getSite(origin: host)
        let chain = site.flatMap { ChainManager.shared.getChain(serverId: $0.chain) }

        return NavigationView {
            Form {
                Section(header: Text(L("Website"))) {
                    Text(pageTitle.isEmpty ? (pageURL?.host ?? "Unknown") : pageTitle)
                    Text(pageURL?.absoluteString ?? "-")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    Text(pageURL?.host ?? "-")
                        .font(.footnote)
                        .textSelection(.enabled)
                }

                Section(header: Text(L("Source"))) {
                    Text(site != nil ? L("Permission Record") : L("Live WebView URL"))
                    Text(site?.origin ?? normalizedOrigin(from: pageURL))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                Section(header: Text(L("Connection"))) {
                    Text(site?.isConnected == true ? L("Connected") : L("Not connected"))
                    Text(site?.account?.address ?? "-")
                        .font(.footnote)
                        .textSelection(.enabled)
                    Text(chain?.name ?? "-")
                }
            }
            .navigationTitle(L("Site Info"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Done")) { showSiteInfo = false }
                }
            }
        }
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
                    ForEach(DAppBookmarkManager.popularDApps) { dapp in
                        Button(action: { navigateTo(dapp.url) }) {
                            VStack(spacing: 8) {
                                dappIcon(title: dapp.title, iconURL: dapp.iconURL, size: 48)
                                Text(dapp.title)
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
                        Button(action: {
                            if site.origin.hasPrefix("http://") || site.origin.hasPrefix("https://") {
                                navigateTo(site.origin)
                            } else {
                                navigateTo("https://\(site.origin)")
                            }
                        }) {
                            let siteURL = site.origin.hasPrefix("http://") || site.origin.hasPrefix("https://")
                                ? site.origin
                                : "https://\(site.origin)"
                            HStack {
                                dappIcon(
                                    title: site.name,
                                    iconURL: site.icon ?? DAppBookmarkManager.faviconURL(for: siteURL),
                                    size: 32
                                )
                                VStack(alignment: .leading) {
                                    Text(site.name).font(.subheadline).foregroundColor(.primary)
                                    Text(siteURL).font(.caption).foregroundColor(.secondary)
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
        guard let target = normalizedNavigationURL(from: urlString) else { return }
        currentURL = target
        urlString = target.absoluteString
    }
    
    private func navigateTo(_ urlStr: String) {
        urlString = urlStr
        navigateToURL()
    }
    
    private func addBookmark() {
        guard let url = currentURL else { return }
        let title = pageTitle.isEmpty ? (url.host ?? "Unknown") : pageTitle
        let iconURL = DAppBookmarkManager.faviconURL(for: url.absoluteString)
        DispatchQueue.main.async {
            bookmarkManager.addBookmark(
                url: url.absoluteString,
                title: title,
                iconURL: iconURL
            )
        }
    }

    private func removeBookmarks(at offsets: IndexSet) {
        let targets = offsets.map { bookmarkManager.bookmarks[$0] }
        targets.forEach { bookmarkManager.removeBookmark(id: $0.id) }
    }

    private func exitToHome() {
        currentURL = nil
        pageTitle = ""
        urlString = ""
        browserNavigation.currentURL = nil
    }

    private func normalizedOrigin(from url: URL?) -> String {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased() else {
            return "-"
        }

        var origin = "\(scheme)://\(host)"
        if let port = url.port {
            let isDefaultPort = (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
            if !isDefaultPort {
                origin += ":\(port)"
            }
        }
        return origin
    }

    private func normalizedNavigationURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directURL = URL(string: trimmed), let scheme = directURL.scheme?.lowercased() {
            guard scheme == "http" || scheme == "https" else {
                return searchURL(for: trimmed)
            }
            return directURL
        }

        if trimmed.contains("."), !trimmed.contains(" "), let hostURL = URL(string: "https://\(trimmed)") {
            return hostURL
        }

        return searchURL(for: trimmed)
    }

    private func searchURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    @ViewBuilder
    private func dappIcon(title: String, iconURL: String, size: CGFloat) -> some View {
        if let url = URL(string: iconURL), !iconURL.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size / 4))
                default:
                    fallbackDappIcon(title: title, size: size)
                }
            }
        } else {
            fallbackDappIcon(title: title, size: size)
        }
    }

    private func fallbackDappIcon(title: String, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size / 4)
            .fill(Color.blue.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Text(String(title.prefix(1)).uppercased())
                    .font(size >= 40 ? .title3 : .caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            )
    }
}

final class DAppBrowserNavigationState: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var currentURL: URL?

    weak var webView: WKWebView?

    func attach(webView: WKWebView) {
        self.webView = webView
        sync(with: webView)
    }

    func sync(with webView: WKWebView?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.canGoBack = webView?.canGoBack ?? false
            self.canGoForward = webView?.canGoForward ?? false
            self.currentURL = webView?.url
        }
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
}

/// WKWebView wrapper for DApp interaction
struct DAppWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    var onApprovalRequest: ((ApprovalRequest, @escaping (Any?, String?, Int?) -> Void) -> Void)?
    var onPageVisited: ((URL, String, String?) -> Void)?
    var onURLChange: ((URL?) -> Void)?
    var navigationState: DAppBrowserNavigationState
    
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
        context.coordinator.attach(webView: webView)
        navigationState.attach(webView: webView)
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.attach(webView: webView)
        navigationState.attach(webView: webView)
        if context.coordinator.shouldReload(for: url, current: webView.url) {
            webView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        struct ProviderError: Error {
            let code: Int
            let message: String
        }

        var parent: DAppWebView
        private weak var webView: WKWebView?
        private var cancellables = Set<AnyCancellable>()
        private var didObserveState = false
        private var lastAccount: String?
        private var lastChainHex: String?
        private var lastRequestedURLString: String?

        init(_ parent: DAppWebView) {
            self.parent = parent
        }

        func attach(webView: WKWebView) {
            self.webView = webView
            if !didObserveState {
                observeProviderStateChanges()
                didObserveState = true
            }
        }

        func shouldReload(for targetURL: URL, current currentURL: URL?) -> Bool {
            let target = normalizedURLString(targetURL)

            if lastRequestedURLString == target {
                return false
            }

            if let currentURL, normalizedURLString(currentURL) == target {
                lastRequestedURLString = target
                return false
            }

            lastRequestedURLString = target
            return true
        }

        private func normalizedURLString(_ url: URL) -> String {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.fragment = nil
            return components?.string ?? url.absoluteString
        }

        private func observeProviderStateChanges() {
            KeyringManager.shared.$currentAccount
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.refreshProviderState(emitEvents: true)
                }
                .store(in: &cancellables)

            ChainManager.shared.$selectedChain
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.refreshProviderState(emitEvents: true)
                }
                .store(in: &cancellables)

            DAppPermissionManager.shared.$connectedSites
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.refreshProviderState(emitEvents: true)
                }
                .store(in: &cancellables)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.navigationState.sync(with: webView)
            parent.onURLChange?(webView.url)
            Task { @MainActor in parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.navigationState.sync(with: webView)
            parent.onURLChange?(webView.url)
            if let currentURL = webView.url {
                lastRequestedURLString = normalizedURLString(currentURL)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                parent.isLoading = false
                parent.pageTitle = webView.title ?? ""
            }
            parent.navigationState.sync(with: webView)
            parent.onURLChange?(webView.url)
            if let currentURL = webView.url {
                lastRequestedURLString = normalizedURLString(currentURL)
            }

            captureFavicon(in: webView) { [weak self] iconURL in
                guard let self, let currentURL = webView.url else { return }
                self.parent.onPageVisited?(currentURL, webView.title ?? "", iconURL)
            }
            refreshProviderState(emitEvents: true)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.navigationState.sync(with: webView)
            Task { @MainActor in parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.navigationState.sync(with: webView)
            Task { @MainActor in parent.isLoading = false }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let targetURL = navigationAction.request.url,
                  let scheme = targetURL.scheme?.lowercased() else {
                decisionHandler(.allow)
                return
            }

            if scheme == "http" || scheme == "https" {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        private func captureFavicon(in webView: WKWebView, completion: @escaping (String?) -> Void) {
            let script = """
            (() => {
              const icon = document.querySelector('link[rel~="icon"]') || document.querySelector('link[rel="shortcut icon"]');
              return icon && icon.href ? icon.href : null;
            })();
            """
            webView.evaluateJavaScript(script) { result, _ in
                completion(result as? String)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "rabbyProvider",
                  let body = message.body as? [String: Any],
                  let method = body["method"] as? String else { return }

            let callbackId = body["id"] as? String

            switch method {
            case "eth_requestAccounts":
                requestAccounts(shouldPromptConnect: true, webView: message.webView) { result in
                    self.respond(with: result, webView: message.webView, callbackId: callbackId)
                }
            case "eth_accounts":
                requestAccounts(shouldPromptConnect: false, webView: message.webView) { result in
                    self.respond(with: result, webView: message.webView, callbackId: callbackId)
                }
            case "eth_coinbase":
                requestAccounts(shouldPromptConnect: false, webView: message.webView) { result in
                    switch result {
                    case .success(let accounts):
                        self.respondToJS(message.webView, id: callbackId, result: accounts.first ?? NSNull())
                    case .failure(let error):
                        self.respondToJS(message.webView, id: callbackId, result: NSNull(), error: error.message, errorCode: error.code)
                    }
                }
            case "eth_chainId":
                let chain = selectedChain(for: currentOrigin(from: message.webView))
                respondToJS(message.webView, id: callbackId, result: chainHex(chain.id))
            case "net_version":
                let chain = selectedChain(for: currentOrigin(from: message.webView))
                respondToJS(message.webView, id: callbackId, result: String(chain.id))
            case "wallet_getPermissions":
                handleGetPermissions(callbackId: callbackId, webView: message.webView)
            case "wallet_requestPermissions":
                handleRequestPermissions(body, callbackId: callbackId, webView: message.webView)
            case "wallet_revokePermissions":
                handleRevokePermissions(body, callbackId: callbackId, webView: message.webView)
            case "wallet_switchEthereumChain":
                handleSwitchChain(body, callbackId: callbackId, webView: message.webView)
            case "wallet_addEthereumChain":
                handleAddChain(body, callbackId: callbackId, webView: message.webView)
            case "eth_sendTransaction":
                handleSendTransaction(body, callbackId: callbackId, webView: message.webView)
            case "personal_sign", "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
                handleSignMessage(body, method: method, callbackId: callbackId, webView: message.webView)
            default:
                if method.hasPrefix("eth_") || method.hasPrefix("net_") {
                    handleRPCPassthrough(body, callbackId: callbackId, webView: message.webView)
                } else {
                    respondToJS(
                        message.webView,
                        id: callbackId,
                        result: NSNull(),
                        error: "Unsupported method: \(method)",
                        errorCode: 4200
                    )
                }
            }
        }

        private func requestAccounts(
            shouldPromptConnect: Bool,
            webView: WKWebView?,
            completion: @escaping (Result<[String], ProviderError>) -> Void
        ) {
            guard let origin = currentOrigin(from: webView) else {
                completion(.failure(ProviderError(code: 4100, message: "Unauthorized")))
                return
            }

            if let account = connectedAddress(for: origin) {
                completion(.success([account]))
                return
            }

            guard shouldPromptConnect else {
                completion(.success([]))
                return
            }

            guard KeyringManager.shared.currentAccount != nil else {
                completion(.failure(ProviderError(code: 4100, message: "No active account")))
                return
            }

            let dappURL = webView?.url?.absoluteString ?? origin

            Task { @MainActor in
                if let autoAddress = await DAppConnectSheet.autoConnectAddress(for: dappURL) {
                    completion(.success([autoAddress]))
                    self.refreshProviderState(emitEvents: true)
                    return
                }

                let chain = self.selectedChain(for: origin)
                let request = ApprovalRequest(
                    id: UUID().uuidString,
                    from: KeyringManager.shared.currentAccount?.address ?? "",
                    to: nil,
                    value: nil,
                    data: nil,
                    message: nil,
                    typedDataJSON: nil,
                    signMethod: "eth_requestAccounts",
                    chainId: chain.id,
                    origin: dappURL,
                    siteName: webView?.title ?? origin,
                    iconUrl: DAppBookmarkManager.faviconURL(for: dappURL),
                    isEIP1559: chain.isEIP1559,
                    type: .connect
                )

                let reply: (Any?, String?, Int?) -> Void = { [weak self] result, error, errorCode in
                    if let error {
                        completion(.failure(ProviderError(code: errorCode ?? 4001, message: error)))
                        return
                    }
                    if let addresses = result as? [String], !addresses.isEmpty {
                        completion(.success(addresses))
                    } else if let address = result as? String {
                        completion(.success([address]))
                    } else {
                        completion(.failure(ProviderError(code: 4001, message: "Connection rejected")))
                    }
                    self?.refreshProviderState(emitEvents: true)
                }
                self.parent.onApprovalRequest?(request, reply)
            }
        }

        private func handleGetPermissions(callbackId: String?, webView: WKWebView?) {
            guard let origin = currentOrigin(from: webView),
                  DAppPermissionManager.shared.isConnected(origin: origin) else {
                respondToJS(webView, id: callbackId, result: [])
                return
            }
            respondToJS(webView, id: callbackId, result: [["parentCapability": "eth_accounts"]])
        }

        private func handleRequestPermissions(_ body: [String: Any], callbackId: String?, webView: WKWebView?) {
            let wantsAccounts = (body["params"] as? [[String: Any]])?.first?.keys.contains("eth_accounts") ?? false
            guard wantsAccounts else {
                respondToJS(webView, id: callbackId, result: [])
                return
            }

            requestAccounts(shouldPromptConnect: true, webView: webView) { result in
                switch result {
                case .success:
                    self.respondToJS(webView, id: callbackId, result: [["parentCapability": "eth_accounts"]])
                case .failure(let error):
                    self.respondToJS(webView, id: callbackId, result: NSNull(), error: error.message, errorCode: error.code)
                }
            }
        }

        private func handleRevokePermissions(_ body: [String: Any], callbackId: String?, webView: WKWebView?) {
            guard let origin = currentOrigin(from: webView) else {
                respondToJS(webView, id: callbackId, result: NSNull())
                return
            }

            let shouldRevoke = (body["params"] as? [[String: Any]])?.first?.keys.contains("eth_accounts") ?? true
            if shouldRevoke {
                DAppPermissionManager.shared.disconnectSite(origin: origin)
                refreshProviderState(emitEvents: true)
            }
            respondToJS(webView, id: callbackId, result: NSNull())
        }

        private func handleSwitchChain(_ body: [String: Any], callbackId: String?, webView: WKWebView?) {
            guard let origin = currentOrigin(from: webView),
                  DAppPermissionManager.shared.isConnected(origin: origin) else {
                respondToJS(webView, id: callbackId, result: NSNull(), error: "Unauthorized", errorCode: 4100)
                return
            }

            guard let params = body["params"] as? [[String: Any]],
                  let chainValue = params.first?["chainId"],
                  let chainId = parseChainID(chainValue),
                  let chain = ChainManager.shared.getChain(id: chainId) else {
                respondToJS(
                    webView,
                    id: callbackId,
                    result: NSNull(),
                    error: "Unrecognized chain ID. Try adding the chain using wallet_addEthereumChain first.",
                    errorCode: 4902
                )
                return
            }

            DAppPermissionManager.shared.setSiteChain(origin: origin, chain: chain.serverId)
            ChainManager.shared.selectChain(chain)
            respondToJS(webView, id: callbackId, result: NSNull())
            refreshProviderState(emitEvents: true)
        }

        private func handleAddChain(_ body: [String: Any], callbackId: String?, webView: WKWebView?) {
            guard let params = body["params"] as? [[String: Any]],
                  let chainValue = params.first?["chainId"],
                  let chainId = parseChainID(chainValue),
                  let chain = ChainManager.shared.getChain(id: chainId) else {
                respondToJS(webView, id: callbackId, result: NSNull(), error: "This chain is not supported by Rabby yet.", errorCode: 4902)
                return
            }

            if let origin = currentOrigin(from: webView) {
                DAppPermissionManager.shared.setSiteChain(origin: origin, chain: chain.serverId)
            }
            ChainManager.shared.selectChain(chain)
            respondToJS(webView, id: callbackId, result: NSNull())
            refreshProviderState(emitEvents: true)
        }

        private func handleSendTransaction(_ body: [String: Any], callbackId: String?, webView: WKWebView?) {
            guard let origin = currentOrigin(from: webView),
                  let activeAddress = connectedAddress(for: origin) else {
                respondToJS(webView, id: callbackId, result: NSNull(), error: "Unauthorized", errorCode: 4100)
                return
            }

            guard let params = body["params"] as? [[String: Any]], var tx = params.first else {
                respondToJS(webView, id: callbackId, result: NSNull(), error: "Invalid params", errorCode: -32602)
                return
            }

            if let from = tx["from"] as? String, from.lowercased() != activeAddress.lowercased() {
                respondToJS(webView, id: callbackId, result: NSNull(), error: "from should be same as current account", errorCode: -32602)
                return
            }
            tx["from"] = activeAddress

            let chain = selectedChain(for: origin)
            let request = ApprovalRequest(
                id: callbackId ?? UUID().uuidString,
                from: activeAddress,
                to: tx["to"] as? String,
                value: tx["value"] as? String,
                data: tx["data"] as? String,
                nonce: tx["nonce"] as? String,
                gas: tx["gas"] as? String,
                gasLimit: tx["gasLimit"] as? String,
                gasPrice: tx["gasPrice"] as? String,
                maxFeePerGas: tx["maxFeePerGas"] as? String,
                maxPriorityFeePerGas: tx["maxPriorityFeePerGas"] as? String,
                message: nil,
                typedDataJSON: nil,
                signMethod: "eth_sendTransaction",
                chainId: chain.id,
                origin: origin,
                siteName: webView?.title,
                iconUrl: DAppBookmarkManager.faviconURL(for: webView?.url?.absoluteString ?? origin),
                isEIP1559: chain.isEIP1559,
                type: .signTx
            )

            let reply: (Any?, String?, Int?) -> Void = { [weak self, weak webView] result, error, errorCode in
                if let error {
                    self?.respondToJS(webView, id: callbackId, result: NSNull(), error: error, errorCode: errorCode)
                } else {
                    self?.respondToJS(webView, id: callbackId, result: result ?? NSNull())
                }
            }
            Task { @MainActor in parent.onApprovalRequest?(request, reply) }
        }

        private func handleSignMessage(_ body: [String: Any], method: String, callbackId: String?, webView: WKWebView?) {
            guard let origin = currentOrigin(from: webView),
                  let activeAddress = connectedAddress(for: origin) else {
                respondToJS(webView, id: callbackId, result: NSNull(), error: "Unauthorized", errorCode: 4100)
                return
            }

            guard let params = body["params"] as? [Any], params.count >= 2 else {
                respondToJS(webView, id: callbackId, result: NSNull(), error: "Invalid params", errorCode: -32602)
                return
            }

            func isAddress(_ value: Any) -> Bool {
                guard let s = value as? String else { return false }
                return EthereumUtil.isValidAddress(s)
            }

            let request: ApprovalRequest
            let chain = selectedChain(for: origin)
            switch method {
            case "personal_sign":
                var messageParam = params[0]
                var addressParam = params[1]
                if isAddress(messageParam) && !isAddress(addressParam) {
                    swap(&messageParam, &addressParam)
                }
                guard let address = addressParam as? String else {
                    respondToJS(webView, id: callbackId, result: NSNull(), error: "Invalid params", errorCode: -32602)
                    return
                }
                guard address.lowercased() == activeAddress.lowercased() else {
                    respondToJS(webView, id: callbackId, result: NSNull(), error: "from should be same as current account", errorCode: -32602)
                    return
                }
                request = ApprovalRequest(
                    id: callbackId ?? UUID().uuidString,
                    from: address,
                    to: nil,
                    value: nil,
                    data: nil,
                    message: messageParam as? String ?? "",
                    typedDataJSON: nil,
                    signMethod: method,
                    chainId: chain.id,
                    origin: origin,
                    siteName: webView?.title,
                    iconUrl: DAppBookmarkManager.faviconURL(for: webView?.url?.absoluteString ?? origin),
                    isEIP1559: chain.isEIP1559,
                    type: .signText
                )
            case "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
                guard let address = params[0] as? String else {
                    respondToJS(webView, id: callbackId, result: NSNull(), error: "Invalid params", errorCode: -32602)
                    return
                }
                guard address.lowercased() == activeAddress.lowercased() else {
                    respondToJS(webView, id: callbackId, result: NSNull(), error: "from should be same as current account", errorCode: -32602)
                    return
                }

                let typedDataJSON: String
                if let jsonString = params[1] as? String {
                    typedDataJSON = jsonString
                } else {
                    let obj = params[1]
                    guard JSONSerialization.isValidJSONObject(obj),
                          let data = try? JSONSerialization.data(withJSONObject: obj),
                          let jsonString = String(data: data, encoding: .utf8) else {
                        respondToJS(webView, id: callbackId, result: NSNull(), error: "Invalid typed data", errorCode: -32602)
                        return
                    }
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
                    chainId: chain.id,
                    origin: origin,
                    siteName: webView?.title,
                    iconUrl: DAppBookmarkManager.faviconURL(for: webView?.url?.absoluteString ?? origin),
                    isEIP1559: chain.isEIP1559,
                    type: .signTypedData
                )
            default:
                respondToJS(webView, id: callbackId, result: NSNull(), error: "Unsupported method", errorCode: 4200)
                return
            }

            let reply: (Any?, String?, Int?) -> Void = { [weak self, weak webView] result, error, errorCode in
                if let error {
                    self?.respondToJS(webView, id: callbackId, result: NSNull(), error: error, errorCode: errorCode)
                } else {
                    self?.respondToJS(webView, id: callbackId, result: result ?? NSNull())
                }
            }
            Task { @MainActor in parent.onApprovalRequest?(request, reply) }
        }

        private func handleRPCPassthrough(_ body: [String: Any], callbackId: String?, webView: WKWebView?) {
            guard let method = body["method"] as? String else {
                respondToJS(webView, id: callbackId, result: NSNull(), error: "Invalid method", errorCode: -32600)
                return
            }

            let params = body["params"] as? [Any] ?? []
            let chain = selectedChain(for: currentOrigin(from: webView))
            let rpcURLString: String
            if let effectiveRPC = RPCManager.shared.getEffectiveRPC(chainId: chain.id) {
                rpcURLString = effectiveRPC
            } else {
                rpcURLString = ChainManager.shared.getRPCUrl(chain: chain.serverId)
            }

            guard let rpcURL = URL(string: rpcURLString) else {
                respondToJS(webView, id: callbackId, result: NSNull(), error: "Invalid RPC URL", errorCode: -32603)
                return
            }

            Task {
                do {
                    let result = try await NetworkManager.shared.sendRPCRequest(
                        method: method,
                        params: params,
                        rpcURL: rpcURL,
                        responseType: AnyCodable.self
                    )
                    self.respondToJS(webView, id: callbackId, result: result.value)
                } catch {
                    self.respondToJS(webView, id: callbackId, result: NSNull(), error: error.localizedDescription, errorCode: -32603)
                }
            }
        }

        private func currentOrigin(from webView: WKWebView?) -> String? {
            guard let url = webView?.url,
                  let scheme = url.scheme?.lowercased(),
                  let host = url.host?.lowercased(),
                  !host.isEmpty else {
                return nil
            }

            var origin = "\(scheme)://\(host)"
            if let port = url.port {
                let isDefaultPort = (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
                if !isDefaultPort {
                    origin += ":\(port)"
                }
            }
            return origin
        }

        private func connectedAddress(for origin: String) -> String? {
            guard let site = DAppPermissionManager.shared.getSite(origin: origin), site.isConnected else {
                return nil
            }
            return site.account?.address ?? KeyringManager.shared.currentAccount?.address
        }

        private func selectedChain(for origin: String?) -> Chain {
            if let origin,
               let site = DAppPermissionManager.shared.getSite(origin: origin),
               site.isConnected,
               let chain = ChainManager.shared.getChain(serverId: site.chain) {
                return chain
            }
            return ChainManager.shared.selectedChain ?? Chain(id: "eth")
        }

        private func parseChainID(_ value: Any) -> Int? {
            if let intValue = value as? Int { return intValue }
            guard let text = value as? String else { return nil }
            if text.hasPrefix("0x") || text.hasPrefix("0X") {
                return Int(text.dropFirst(2), radix: 16)
            }
            return Int(text)
        }

        private func chainHex(_ value: Int) -> String {
            "0x" + String(value, radix: 16)
        }

        private func refreshProviderState(emitEvents: Bool) {
            guard let webView else { return }
            let origin = currentOrigin(from: webView)
            let account = origin.flatMap { connectedAddress(for: $0) }
            let chain = selectedChain(for: origin)
            let currentChainHex = chainHex(chain.id)

            let stateScript = """
            (() => {
              if (!window.ethereum) return;
              window.ethereum.selectedAddress = \(jsLiteral(account ?? NSNull()));
              window.ethereum.chainId = \(jsLiteral(currentChainHex));
              window.ethereum.networkVersion = \(jsLiteral(String(chain.id)));
            })();
            """
            webView.evaluateJavaScript(stateScript, completionHandler: nil)

            guard emitEvents else {
                lastAccount = account
                lastChainHex = currentChainHex
                return
            }

            if lastChainHex != nil, lastChainHex != currentChainHex {
                let chainChanged = "window.ethereum && window.ethereum.emit(\"chainChanged\", \(jsLiteral(currentChainHex)));"
                webView.evaluateJavaScript(chainChanged, completionHandler: nil)
            }

            if lastAccount != account {
                let accounts = account.map { [$0] } ?? []
                let accountsChanged = "window.ethereum && window.ethereum.emit(\"accountsChanged\", \(jsLiteral(accounts)));"
                webView.evaluateJavaScript(accountsChanged, completionHandler: nil)

                if lastAccount == nil, account != nil {
                    let connect = "window.ethereum && window.ethereum.emit(\"connect\", { chainId: \(jsLiteral(currentChainHex)) });"
                    webView.evaluateJavaScript(connect, completionHandler: nil)
                } else if lastAccount != nil, account == nil {
                    let disconnect = "window.ethereum && window.ethereum.emit(\"disconnect\", { code: 4900, message: \"Disconnected\" });"
                    webView.evaluateJavaScript(disconnect, completionHandler: nil)
                }
            }

            lastAccount = account
            lastChainHex = currentChainHex
        }

        private func respond(with result: Result<[String], ProviderError>, webView: WKWebView?, callbackId: String?) {
            switch result {
            case .success(let accounts):
                respondToJS(webView, id: callbackId, result: accounts)
                refreshProviderState(emitEvents: true)
            case .failure(let error):
                respondToJS(webView, id: callbackId, result: NSNull(), error: error.message, errorCode: error.code)
            }
        }

        private func respondToJS(_ webView: WKWebView?, id: String?, result: Any, error: String? = nil, errorCode: Int? = nil) {
            guard let webView, let callbackId = id else { return }
            let callbackLiteral = jsLiteral(callbackId)

            if let error {
                let js = "window.ethereum && window.ethereum._resolveCallback(\(callbackLiteral), null, \(jsLiteral(error)), \(errorCode ?? -1));"
                webView.evaluateJavaScript(js, completionHandler: nil)
                return
            }

            let js = "window.ethereum && window.ethereum._resolveCallback(\(callbackLiteral), \(jsLiteral(result)), null, null);"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private func jsLiteral(_ value: Any) -> String {
            if value is NSNull { return "null" }
            if let bool = value as? Bool { return bool ? "true" : "false" }
            if let number = value as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    return number.boolValue ? "true" : "false"
                }
                return number.stringValue
            }
            if let string = value as? String {
                if let data = try? JSONEncoder().encode(string),
                   let json = String(data: data, encoding: .utf8) {
                    return json
                }
                return "\"\""
            }
            if let array = value as? [Any],
               JSONSerialization.isValidJSONObject(array),
               let data = try? JSONSerialization.data(withJSONObject: array),
               let json = String(data: data, encoding: .utf8) {
                return json
            }
            if let dict = value as? [String: Any],
               JSONSerialization.isValidJSONObject(dict),
               let data = try? JSONSerialization.data(withJSONObject: dict),
               let json = String(data: data, encoding: .utf8) {
                return json
            }
            if let wrapped = value as? AnyCodable {
                return jsLiteral(wrapped.value)
            }
            if let data = try? JSONEncoder().encode(String(describing: value)),
               let json = String(data: data, encoding: .utf8) {
                return json
            }
            return "\"\""
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
                networkVersion: '1',
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
                isConnected: function() { return true; },
                _metamask: {
                    isUnlocked: function() { return Promise.resolve(true); }
                },
            };
            window.dispatchEvent(new Event('ethereum#initialized'));
        })();
        """
    }
}
