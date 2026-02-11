import SwiftUI

/// Rabby Wallet SwiftUI App Entry Point
@main
struct RabbyMobileApp: App {
    @UIApplicationDelegateAdaptor(RabbyAppDelegate.self) var appDelegate
    @StateObject private var autoLockManager = AutoLockManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    autoLockManager.appDidEnterBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    autoLockManager.appDidBecomeActive()
                }
                .preferredColorScheme(colorScheme)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch PreferenceManager.shared.themeMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Handle WalletConnect deep links (wc: URI scheme)
        if url.scheme == "wc" {
            let wcURI = url.absoluteString
            Task { @MainActor in
                try? await WalletConnectManager.shared.pair(uri: wcURI)
            }
        }
        // Handle rabbywallet:// scheme
        else if url.scheme == "rabbywallet" {
            if let host = url.host {
                switch host {
                case "wc":
                    if let wcURI = url.queryParameters["uri"] {
                        Task { @MainActor in
                            try? await WalletConnectManager.shared.pair(uri: wcURI)
                        }
                    }
                default:
                    break
                }
            }
        }
    }
}

/// Native Swift AppDelegate (replaces React Native AppDelegate)
class RabbyAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize core services
        initializeServices()
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        return configuration
    }
    
    private func initializeServices() {
        // Initialize storage
        _ = StorageManager.shared
        
        // Initialize chain manager
        Task { @MainActor in
            _ = ChainManager.shared
            await SyncChainManager.shared.syncIfNeeded()
        }
        
        // Initialize auto-lock
        _ = AutoLockManager.shared
        
        // Initialize I18n
        I18nManager.shared.initialize()
        
        // Register for remote notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs Device Token: \(token)")
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle URL schemes
        if url.scheme == "wc" || url.scheme == "rabbywallet" {
            return true
        }
        return false
    }
}

// MARK: - URL Query Parameter Helper
extension URL {
    var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return [:] }
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
    }
}
