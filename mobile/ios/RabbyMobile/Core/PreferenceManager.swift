import Foundation
import Combine

/// Preference Manager - User preferences and app settings
/// Equivalent to Web version's preference service (966 lines)
@MainActor
class PreferenceManager: ObservableObject {
    static let shared = PreferenceManager()
    
    // Current account
    @Published var currentAccount: Account?
    @Published var accounts: [Account] = []
    @Published var hiddenAddresses: [Account] = []
    
    // UI preferences
    @Published var themeMode: ThemeMode = .light
    /// Effective locale used by LocalizationManager (e.g. "en", "zh-CN").
    /// When `localeMode == .system`, this value is automatically derived from iOS settings.
    @Published var locale: String = "en"
    @Published var localeMode: LocaleMode = .system
    @Published var currency: String = "USD"
    
    // Balance cache
    @Published var balanceMap: [String: BalanceInfo] = [:]
    
    // Features
    @Published var isWhitelistEnabled: Bool = false
    @Published var autoLockMinutes: Int = 60
    @Published var showTestnet: Bool = false
    @Published var defaultChain: String = "eth"
    
    // Gas cache
    @Published var gasPriceCache: [String: GasCache] = [:]
    
    // Added tokens
    @Published var addedTokenMap: [String: [String]] = [:]
    
    private let storage = StorageManager.shared
    private let prefKey = "rabby_preferences"
    
    // MARK: - Models
    
    struct Account: Codable, Identifiable, Equatable {
        var id: String { address }
        let type: String
        let address: String
        let brandName: String
        var aliasName: String?
        var displayBrandName: String?
        var index: Int?
        var balance: Double?
    }
    
    enum ThemeMode: String, Codable {
        case light = "light"
        case dark = "dark"
        case system = "system"
    }

    enum LocaleMode: String, Codable {
        case system = "system"
        case custom = "custom"
    }
    
    struct BalanceInfo: Codable {
        let totalUsdValue: Double
        let chainList: [ChainBalance]?
        let updatedAt: Date?
        
        struct ChainBalance: Codable {
            let chainId: String
            let usdValue: Double
        }
    }
    
    struct GasCache: Codable {
        var gasPrice: String?
        var gasLevel: String?
        var lastTimeSelect: String? // "gasLevel" or "gasPrice"
        var expireAt: TimeInterval?
    }
    
    struct PreferenceStore: Codable {
        var currentAccountAddress: String?
        var themeMode: String
        var locale: String
        var localeMode: String?
        var currency: String
        var isWhitelistEnabled: Bool
        var autoLockMinutes: Int
        var showTestnet: Bool
        var defaultChain: String
        var hiddenAddresses: [String]
        var addedTokenMap: [String: [String]]
    }
    
    // MARK: - Initialization
    
    private init() {
        loadPreferences()
        observeSystemLocaleChanges()
    }
    
    // MARK: - Account Management
    
    func setCurrentAccount(_ account: Account) {
        currentAccount = account
        savePreferences()
    }
    
    func getCurrentAccount() -> Account? {
        return currentAccount
    }
    
    func addAccount(_ account: Account) {
        guard !accounts.contains(where: { $0.address.lowercased() == account.address.lowercased() }) else { return }
        accounts.append(account)
    }
    
    func removeAccount(_ address: String) {
        accounts.removeAll { $0.address.lowercased() == address.lowercased() }
        if currentAccount?.address.lowercased() == address.lowercased() {
            currentAccount = accounts.first
        }
        savePreferences()
    }
    
    func setAlias(address: String, alias: String) {
        if let index = accounts.firstIndex(where: { $0.address.lowercased() == address.lowercased() }) {
            accounts[index].aliasName = alias
        }
        if currentAccount?.address.lowercased() == address.lowercased() {
            currentAccount?.aliasName = alias
        }
        savePreferences()
    }
    
    func getAlias(address: String) -> String? {
        return accounts.first(where: { $0.address.lowercased() == address.lowercased() })?.aliasName
    }
    
    func hideAddress(_ address: String) {
        if let account = accounts.first(where: { $0.address.lowercased() == address.lowercased() }) {
            if !hiddenAddresses.contains(where: { $0.address.lowercased() == address.lowercased() }) {
                hiddenAddresses.append(account)
            }
        }
        savePreferences()
    }
    
    func unhideAddress(_ address: String) {
        hiddenAddresses.removeAll { $0.address.lowercased() == address.lowercased() }
        savePreferences()
    }
    
    // MARK: - Balance
    
    func updateBalance(address: String, balance: BalanceInfo) {
        balanceMap[address.lowercased()] = balance
    }
    
    func getBalance(address: String) -> BalanceInfo? {
        return balanceMap[address.lowercased()]
    }
    
    func getTotalBalance() -> Double {
        return balanceMap.values.reduce(0) { $0 + $1.totalUsdValue }
    }
    
    // MARK: - Theme
    
    func setTheme(_ mode: ThemeMode) {
        themeMode = mode
        savePreferences()
    }
    
    // MARK: - Locale

    func setLocale(_ locale: String) {
        localeMode = .custom
        self.locale = locale
        savePreferences()
        // Notify LocalizationManager via NotificationCenter
        NotificationCenter.default.post(
            name: .localeDidChange,
            object: nil,
            userInfo: ["locale": locale]
        )
    }

    func setLocaleModeSystem() {
        localeMode = .system
        let resolved = LocalizationManager.bestSupportedLocale()
        applySystemLocaleIfNeeded(resolved)
        savePreferences()
        NotificationCenter.default.post(
            name: .localeDidChange,
            object: nil,
            userInfo: ["locale": locale]
        )
    }

    /// When in `.system` mode, keep `locale` synced with iOS preferred languages.
    /// - Note: This intentionally does not flip `localeMode`; it only updates the effective `locale`.
    func applySystemLocaleIfNeeded(_ resolvedSystemLocale: String = LocalizationManager.bestSupportedLocale()) {
        guard localeMode == .system else { return }
        if locale != resolvedSystemLocale {
            locale = resolvedSystemLocale
        }
    }
    
    // MARK: - Gas Cache
    
    func getLastTimeGasSelection(chainId: String) -> GasCache? {
        guard let cache = gasPriceCache[chainId] else { return nil }
        if cache.lastTimeSelect == "gasPrice" {
            if Date().timeIntervalSince1970 <= (cache.expireAt ?? 0) {
                return cache
            } else if cache.gasLevel != nil {
                return GasCache(gasLevel: cache.gasLevel, lastTimeSelect: "gasLevel")
            }
            return nil
        }
        return cache
    }
    
    func updateGasSelection(chainId: String, gas: GasCache) {
        var updated = gas
        if gas.lastTimeSelect == "gasPrice" {
            updated.expireAt = Date().timeIntervalSince1970 + 3600
        }
        gasPriceCache[chainId] = updated
    }
    
    // MARK: - Added Tokens
    
    func addToken(address: String, tokenId: String) {
        let lower = address.lowercased()
        var tokens = addedTokenMap[lower] ?? []
        if !tokens.contains(tokenId) {
            tokens.append(tokenId)
            addedTokenMap[lower] = tokens
            savePreferences()
        }
    }
    
    func removeToken(address: String, tokenId: String) {
        let lower = address.lowercased()
        addedTokenMap[lower]?.removeAll { $0 == tokenId }
        savePreferences()
    }
    
    func getAddedTokens(address: String) -> [String] {
        return addedTokenMap[address.lowercased()] ?? []
    }
    
    // MARK: - Whitelist
    
    func setWhitelistEnabled(_ enabled: Bool) {
        isWhitelistEnabled = enabled
        savePreferences()
    }
    
    // MARK: - Private
    
    private func loadPreferences() {
        if let data = storage.getData(forKey: prefKey),
           let store = try? JSONDecoder().decode(PreferenceStore.self, from: data) {
            self.themeMode = ThemeMode(rawValue: store.themeMode) ?? .light
            // Migration:
            // - If `localeMode` exists, honor it.
            // - If missing, treat non-default locales as explicit user choice; treat "en" as system-follow (common case).
            if let rawLocaleMode = store.localeMode,
               let mode = LocaleMode(rawValue: rawLocaleMode) {
                self.localeMode = mode
            } else {
                self.localeMode = (store.locale == "en") ? .system : .custom
            }

            self.locale = store.locale
            // If following system, resolve the effective locale now.
            applySystemLocaleIfNeeded()

            self.currency = store.currency
            self.isWhitelistEnabled = store.isWhitelistEnabled
            self.autoLockMinutes = store.autoLockMinutes
            self.showTestnet = store.showTestnet
            self.defaultChain = store.defaultChain
            self.addedTokenMap = store.addedTokenMap

            // Sync locale to LocalizationManager after loading
            NotificationCenter.default.post(
                name: .localeDidChange,
                object: nil,
                userInfo: ["locale": locale]
            )
        } else {
            // First launch (no saved preferences): default to system language.
            localeMode = .system
            applySystemLocaleIfNeeded()
            NotificationCenter.default.post(
                name: .localeDidChange,
                object: nil,
                userInfo: ["locale": locale]
            )
        }
    }
    
    private func savePreferences() {
        let store = PreferenceStore(
            currentAccountAddress: currentAccount?.address,
            themeMode: themeMode.rawValue,
            locale: locale,
            localeMode: localeMode.rawValue,
            currency: currency,
            isWhitelistEnabled: isWhitelistEnabled,
            autoLockMinutes: autoLockMinutes,
            showTestnet: showTestnet,
            defaultChain: defaultChain,
            hiddenAddresses: hiddenAddresses.map { $0.address },
            addedTokenMap: addedTokenMap
        )
        if let data = try? JSONEncoder().encode(store) {
            storage.setData(data, forKey: prefKey)
        }
    }

    private func observeSystemLocaleChanges() {
        NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                let pref = PreferenceManager.shared
                guard pref.localeMode == .system else { return }
                pref.applySystemLocaleIfNeeded()
                pref.savePreferences()
                NotificationCenter.default.post(
                    name: .localeDidChange,
                    object: nil,
                    userInfo: ["locale": pref.locale]
                )
            }
        }
    }
}
