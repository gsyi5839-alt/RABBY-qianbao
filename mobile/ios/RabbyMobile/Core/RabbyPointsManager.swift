import Foundation

/// Rabby Points Manager - Points/rewards system
/// Corresponds to: src/background/service/rabbyPoints.ts
@MainActor
class RabbyPointsManager: ObservableObject {
    static let shared = RabbyPointsManager()

    @Published var totalPoints: Int = 0
    @Published var rank: Int?
    @Published var referralCode: String?
    @Published var isLoading = false
    @Published var claimHistory: [ClaimRecord] = []

    // Leaderboard
    @Published var leaderboard: [OpenAPIService.LeaderboardEntry] = []
    @Published var leaderboardTotal: Int = 0
    @Published var isLoadingLeaderboard = false

    // Check-in / streak
    @Published var consecutiveDays: Int = 0
    @Published var streakMultiplier: Double = 1.0
    @Published var checkedInDates: Set<String> = [] // "yyyy-MM-dd"
    @Published var alreadyCheckedInToday: Bool = false

    // Points history (paginated)
    @Published var pointsHistory: [OpenAPIService.PointsHistoryItem] = []
    @Published var pointsHistoryHasMore: Bool = false
    @Published var isLoadingHistory = false
    private var historyPage: Int = 1

    // Address verification
    @Published var isAddressVerified: Bool = false

    private let storage = StorageManager.shared
    private let storageKey = "rabby_points"

    struct ClaimRecord: Identifiable, Codable {
        let id: String
        let points: Int
        let claimedAt: Date
        let type: String // "daily", "referral", "transaction", "swap"
    }

    private init() {
        loadFromStorage()
    }

    // MARK: - Public API

    func loadPoints(address: String) async {
        isLoading = true
        do {
            let info = try await OpenAPIService.shared.getRabbyPoints(address: address)
            totalPoints = info.total_points
            rank = info.rank
            referralCode = info.referral_code
            saveToStorage()
        } catch {
            print("RabbyPointsManager: load points failed - \(error)")
        }
        isLoading = false
    }

    func claimDailyPoints(address: String) async throws -> Int {
        isLoading = true
        defer { isLoading = false }

        let info = try await OpenAPIService.shared.claimRabbyPoints(address: address)
        let claimedPoints = info.total_points - totalPoints

        totalPoints = info.total_points
        rank = info.rank

        let record = ClaimRecord(id: UUID().uuidString, points: claimedPoints, claimedAt: Date(), type: "daily")
        claimHistory.insert(record, at: 0)

        // Update check-in state after claiming
        alreadyCheckedInToday = true
        consecutiveDays += 1
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        checkedInDates.insert(dateFormatter.string(from: Date()))

        saveToStorage()
        return claimedPoints
    }

    func getReferralLink() -> String? {
        guard let code = referralCode else { return nil }
        return "https://rabby.io/points?ref=\(code)"
    }

    // MARK: - Leaderboard

    func getLeaderboard(page: Int = 1, limit: Int = 10) async throws -> [OpenAPIService.LeaderboardEntry] {
        isLoadingLeaderboard = true
        defer { isLoadingLeaderboard = false }

        let response = try await OpenAPIService.shared.getPointsLeaderboard(page: page, limit: limit)
        if page == 1 {
            leaderboard = response.list
        } else {
            leaderboard.append(contentsOf: response.list)
        }
        leaderboardTotal = response.total
        return response.list
    }

    func loadTopLeaderboard() async {
        _ = try? await getLeaderboard(page: 1, limit: 10)
    }

    func loadFullLeaderboard(page: Int = 1) async {
        _ = try? await getLeaderboard(page: page, limit: 100)
    }

    // MARK: - Address Verification

    func verifyAddress(address: String, signature: String) async throws -> Bool {
        let response = try await OpenAPIService.shared.verifyPointsAddress(
            address: address,
            signature: signature
        )
        if response.success {
            isAddressVerified = true
            if let awarded = response.points_awarded {
                totalPoints += awarded
                let record = ClaimRecord(
                    id: UUID().uuidString,
                    points: awarded,
                    claimedAt: Date(),
                    type: "verification"
                )
                claimHistory.insert(record, at: 0)
            }
            saveToStorage()
        }
        return response.success
    }

    /// Build the message to sign for address verification
    func buildVerificationMessage(address: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "Rabby Points: Verify ownership of \(address) at \(timestamp)"
    }

    // MARK: - Points History (paginated)

    func getPointsHistory(address: String, page: Int = 1, limit: Int = 20) async throws -> [OpenAPIService.PointsHistoryItem] {
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        let response = try await OpenAPIService.shared.getPointsHistory(
            address: address,
            page: page,
            limit: limit
        )
        if page == 1 {
            pointsHistory = response.list
        } else {
            pointsHistory.append(contentsOf: response.list)
        }
        pointsHistoryHasMore = response.has_more
        historyPage = page
        return response.list
    }

    func loadNextHistoryPage(address: String) async {
        guard pointsHistoryHasMore, !isLoadingHistory else { return }
        _ = try? await getPointsHistory(address: address, page: historyPage + 1)
    }

    // MARK: - Check-in Info

    func loadCheckInInfo(address: String) async {
        do {
            let info = try await OpenAPIService.shared.getCheckInInfo(address: address)
            consecutiveDays = info.consecutive_days
            streakMultiplier = info.multiplier
            checkedInDates = Set(info.checked_in_dates)
            alreadyCheckedInToday = info.already_checked_in_today
        } catch {
            print("RabbyPointsManager: load check-in info failed - \(error)")
        }
    }

    /// Compute the streak multiplier label (e.g. "2x" for 7+ days)
    var streakMultiplierLabel: String {
        if streakMultiplier >= 3.0 {
            return "3x"
        } else if streakMultiplier >= 2.0 {
            return "2x"
        } else if streakMultiplier >= 1.5 {
            return "1.5x"
        } else {
            return "1x"
        }
    }

    // MARK: - Storage

    private func loadFromStorage() {
        totalPoints = storage.getInt(forKey: "\(storageKey)_total")
        let rankValue = storage.getInt(forKey: "\(storageKey)_rank")
        if rankValue > 0 {
            rank = rankValue
        }
        referralCode = storage.getString(forKey: "\(storageKey)_referral")
        if let data = storage.getData(forKey: "\(storageKey)_history"),
           let history = try? JSONDecoder().decode([ClaimRecord].self, from: data) {
            claimHistory = history
        }
        consecutiveDays = storage.getInt(forKey: "\(storageKey)_streak")
        isAddressVerified = storage.getBool(forKey: "\(storageKey)_verified")
    }

    private func saveToStorage() {
        storage.setInt(totalPoints, forKey: "\(storageKey)_total")
        if let rank = rank { storage.setInt(rank, forKey: "\(storageKey)_rank") }
        if let code = referralCode { storage.setString(code, forKey: "\(storageKey)_referral") }
        if let data = try? JSONEncoder().encode(claimHistory) {
            storage.setData(data, forKey: "\(storageKey)_history")
        }
        storage.setInt(consecutiveDays, forKey: "\(storageKey)_streak")
        storage.setBool(isAddressVerified, forKey: "\(storageKey)_verified")
    }
}

/// User Guide Manager - New user onboarding flow
/// Corresponds to: src/background/service/userGuide.ts
@MainActor
class UserGuideManager: ObservableObject {
    static let shared = UserGuideManager()
    
    @Published var hasCompletedGuide: Bool = false
    @Published var currentStep: Int = 0
    @Published var showGuideOverlay: Bool = false
    
    private let storage = StorageManager.shared
    private let storageKey = "user_guide"
    
    let guideSteps: [GuideStep] = [
        GuideStep(id: 0, title: "Welcome to Rabby", description: "Your gateway to DeFi on mobile", icon: "hand.wave.fill"),
        GuideStep(id: 1, title: "Secure Your Wallet", description: "Back up your seed phrase and enable biometrics", icon: "lock.shield.fill"),
        GuideStep(id: 2, title: "Explore DApps", description: "Browse and interact with decentralized applications", icon: "globe"),
        GuideStep(id: 3, title: "Stay Safe", description: "Rabby's security engine checks every transaction", icon: "shield.checkered"),
        GuideStep(id: 4, title: "You're Ready!", description: "Start exploring the world of DeFi", icon: "checkmark.circle.fill"),
    ]
    
    struct GuideStep: Identifiable {
        let id: Int
        let title: String
        let description: String
        let icon: String
    }
    
    private init() {
        hasCompletedGuide = storage.getBool(forKey: "\(storageKey)_completed")
    }
    
    func nextStep() {
        if currentStep < guideSteps.count - 1 {
            currentStep += 1
        } else {
            completeGuide()
        }
    }
    
    func previousStep() {
        if currentStep > 0 { currentStep -= 1 }
    }
    
    func completeGuide() {
        hasCompletedGuide = true
        showGuideOverlay = false
        storage.setBool(true, forKey: "\(storageKey)_completed")
    }
    
    func resetGuide() {
        hasCompletedGuide = false
        currentStep = 0
        storage.setBool(false, forKey: "\(storageKey)_completed")
    }
    
    func showGuide() {
        if !hasCompletedGuide {
            currentStep = 0
            showGuideOverlay = true
        }
    }
}

/// I18n Manager - Internationalization
/// Corresponds to: src/background/service/i18n.ts
class I18nManager: ObservableObject {
    static let shared = I18nManager()
    
    @Published var currentLocale: String = "en"
    
    private let supportedLocales = ["en", "zh-CN", "zh-HK", "ja", "ko", "de", "es", "fr-FR", "pt-BR", "ru", "tr", "vi", "id"]
    private let storage = UserDefaults.standard
    
    private var translations: [String: [String: String]] = [:]
    
    private init() {
        currentLocale = storage.string(forKey: "app_locale") ?? Locale.current.identifier
        // Normalize locale
        if !supportedLocales.contains(currentLocale) {
            currentLocale = "en"
        }
    }
    
    func initialize() {
        loadTranslations()
    }
    
    func setLocale(_ locale: String) {
        guard supportedLocales.contains(locale) else { return }
        currentLocale = locale
        storage.set(locale, forKey: "app_locale")
        loadTranslations()
    }
    
    func t(_ key: String) -> String {
        return translations[currentLocale]?[key] ?? translations["en"]?[key] ?? key
    }
    
    func getSupportedLocales() -> [(code: String, name: String)] {
        return [
            ("en", "English"), ("zh-CN", "简体中文"), ("zh-HK", "繁體中文"),
            ("ja", "日本語"), ("ko", "한국어"), ("de", "Deutsch"),
            ("es", "Español"), ("fr-FR", "Français"), ("pt-BR", "Português"),
            ("ru", "Русский"), ("tr", "Türkçe"), ("vi", "Tiếng Việt"),
            ("id", "Bahasa Indonesia"),
        ]
    }
    
    private func loadTranslations() {
        // Load translations from bundle (JSON files)
        let bundle = Bundle.main
        for locale in supportedLocales {
            let normalizedLocale = locale.replacingOccurrences(of: "-", with: "_")
            if let path = bundle.path(forResource: normalizedLocale, ofType: "json", inDirectory: "locales"),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let dict = try? JSONDecoder().decode([String: String].self, from: data) {
                translations[locale] = dict
            }
        }
    }
}
