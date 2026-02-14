import SwiftUI
import UIKit

// MARK: - Privacy Overlay View

/// Full-screen privacy overlay shown when the app enters background / app-switcher.
/// Uses a gaussian blur material with the Rabby brand logo centered on screen.
struct PrivacyOverlayView: View {
    var body: some View {
        ZStack {
            // Gaussian blur background
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "shield.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 12, y: 4)

                Text("Rabby Wallet")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Privacy Screen Manager

/// Manages a dedicated UIWindow overlay to hide sensitive content when the app
/// is not in the active state (app-switcher, control center, etc.).
@MainActor
final class PrivacyScreenManager: ObservableObject {
    static let shared = PrivacyScreenManager()

    private var privacyWindow: UIWindow?

    private init() {}

    /// Show the privacy overlay window above all other content.
    func showPrivacyScreen() {
        guard privacyWindow == nil else { return }
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear

        let hostingController = UIHostingController(rootView: PrivacyOverlayView())
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        privacyWindow = window
    }

    /// Hide and release the privacy overlay window.
    func hidePrivacyScreen() {
        privacyWindow?.isHidden = true
        privacyWindow = nil
    }
}

// MARK: - App Entry Point

/// Rabby Wallet SwiftUI App Entry Point
@main
struct RabbyMobileApp: App {
    @UIApplicationDelegateAdaptor(RabbyAppDelegate.self) var appDelegate
    @StateObject private var autoLockManager = AutoLockManager.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared
    @StateObject private var localizationManager = LocalizationManager.shared

    private let privacyManager = PrivacyScreenManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                // Force a full SwiftUI rebuild when locale changes so even views that
                // don't directly observe LocalizationManager will refresh their text.
                .id(localizationManager.currentLocale)
                .environmentObject(deepLinkRouter)
                .environmentObject(localizationManager)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    autoLockManager.appDidEnterBackground()
                    privacyManager.showPrivacyScreen()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    autoLockManager.appDidBecomeActive()
                    privacyManager.hidePrivacyScreen()
                }
                .preferredColorScheme(colorScheme)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    handleUniversalLink(userActivity)
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

    // MARK: - URL Handling

    /// Unified handler for all incoming URLs (custom schemes + Universal Links via onOpenURL).
    /// Delegates to DeepLinkRouter for route resolution, then executes immediate actions
    /// like WalletConnect pairing where needed.
    private func handleIncomingURL(_ url: URL) {
        let handled = deepLinkRouter.handleURL(url)

        if handled, let route = deepLinkRouter.pendingRoute {
            executeImmediateAction(for: route)
        }
    }

    /// Handler for Universal Links arriving via NSUserActivity (onContinueUserActivity).
    private func handleUniversalLink(_ userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else { return }

        let handled = deepLinkRouter.handleUniversalLink(url)

        if handled, let route = deepLinkRouter.pendingRoute {
            executeImmediateAction(for: route)
        }
    }

    /// Execute immediate side-effects for routes that need them (e.g. WalletConnect pairing).
    /// Navigation-only routes are handled by the UI layer observing `pendingRoute`.
    private func executeImmediateAction(for route: DeepLinkRoute) {
        switch route {
        case .walletConnect(let uri):
            Task { @MainActor in
                try? await WalletConnectManager.shared.pair(uri: uri)
            }
        default:
            // Other routes are handled by the UI layer observing DeepLinkRouter.pendingRoute.
            // See DeepLinkRouter.swift for integration instructions.
            break
        }
    }
}

// MARK: - RootView Deep Link Integration Guide
//
// To respond to deep link routes in the main tab view, add the following
// observer to the MainTabView or any root-level navigation container:
//
// .onChange(of: DeepLinkRouter.shared.pendingRoute) { route in
//     guard let route = route else { return }
//     switch route {
//     case .walletConnect(let uri):
//         // WalletConnect pairing is handled automatically in RabbyMobileApp.
//         // Optionally show a pairing-in-progress indicator here.
//         break
//     case .send(let to, let amount, let chainId, let token):
//         // Navigate to SendTokenView with pre-filled parameters
//         selectedTab = .send
//     case .swap(let fromToken, let toToken, let chainId):
//         // Navigate to SwapView with pre-filled parameters
//         selectedTab = .swap
//     case .bridge(let fromChain, let toChain):
//         // Navigate to BridgeView with pre-filled parameters
//         selectedTab = .bridge
//     case .dapp(let url):
//         // Open DAppBrowserView with the given URL
//         showDAppBrowser(url: url)
//     case .receive:
//         // Navigate to receive/deposit screen
//         selectedTab = .receive
//     case .settings:
//         // Navigate to settings screen
//         selectedTab = .settings
//     }
//     DeepLinkRouter.shared.clearRoute()
// }

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

        // Initialize database (SQLite)
        _ = DatabaseManager.shared
        print("✅ [RabbyApp] SQLite database initialized")

        // Initialize Localization BEFORE PreferenceManager so the .localeDidChange
        // observer is registered before PreferenceManager.loadPreferences() posts
        // the notification with the user's saved locale.
        _ = LocalizationManager.shared

        // Initialize preferences (locale/theme/currency/etc.)
        _ = PreferenceManager.shared

        // Initialize chain manager
        Task { @MainActor in
            _ = ChainManager.shared
            await SyncChainManager.shared.syncIfNeeded()

            // Migrate data from UserDefaults to SQLite (one-time operation)
            do {
                try await DatabaseMigration.shared.migrateIfNeeded()
                print("✅ [RabbyApp] Database migration completed")
            } catch {
                print("❌ [RabbyApp] Database migration failed: \(error)")
            }
        }

        // Initialize auto-lock
        _ = AutoLockManager.shared

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
        // Delegate all URL handling to DeepLinkRouter
        return DeepLinkRouter.shared.handleURL(url)
    }

    // MARK: - Universal Links via UIApplicationDelegate

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        return DeepLinkRouter.shared.handleUniversalLink(url)
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
