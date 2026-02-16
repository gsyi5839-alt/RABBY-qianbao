import Foundation
import Combine
import LocalAuthentication
import UIKit

/// Auto Lock Manager - Auto-lock wallet after inactivity
/// Equivalent to Web version's autoLock service
///
/// **实现方式**：混合模式
/// - 前台：使用精确的 Timer.scheduledTimer (单次触发)
/// - 后台：记录进入后台时间，回到前台时计算总不活动时长
/// - 持久化：保存 lastActiveTime 到 UserDefaults，支持应用重启后恢复
@MainActor
class AutoLockManager: ObservableObject {
    static let shared = AutoLockManager()

    @Published var isLocked = false
    @Published var autoLockEnabled = true
    @Published var autoLockDuration: TimeInterval = 3600 // 1 hour default

    private var lastActiveTime: Date = Date()
    private var backgroundTime: Date?  // 进入后台的时间
    private var timer: Timer?

    private let storage = StorageManager.shared
    private let lockKey = "rabby_auto_lock_settings"
    private let lastActiveTimeKey = "rabby_last_active_time"

    // Auto lock duration options (in seconds)
    enum LockDuration: TimeInterval, CaseIterable {
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case thirtyMinutes = 1800
        case oneHour = 3600
        case never = 0

        var displayName: String {
            switch self {
            case .oneMinute: return "1 minute"
            case .fiveMinutes: return "5 minutes"
            case .fifteenMinutes: return "15 minutes"
            case .thirtyMinutes: return "30 minutes"
            case .oneHour: return "1 hour"
            case .never: return "Never"
            }
        }
    }

    struct LockSettings: Codable {
        var enabled: Bool
        var duration: TimeInterval
    }

    // MARK: - Initialization

    private var observers: [NSObjectProtocol] = []
    private var lastUpdateTime: Date = Date()  // 用于防抖

    private init() {
        loadSettings()
        loadLastActiveTime()
        startTimer()

        // Listen for app lifecycle events using closure-based API (compatible with @MainActor)
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.appDidEnterBackground()
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.appWillEnterForeground()
                }
            }
        )

        // Safety net: when keyring is unlocked via password, also clear autoLock.
        // This ensures autoLock.isLocked is always reset even if the caller forgets.
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .keyringUnlocked,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isLocked = false
                    self?.updateActivity()
                    print("[AutoLockManager] Received keyringUnlocked — isLocked = false, activity updated")
                }
            }
        )
    }

    deinit {
        timer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Public Methods

    /// Update last active time (with debounce to avoid high-frequency resets)
    func updateActivity() {
        let now = Date()

        // ✅ 防抖：1 秒内只重置一次，避免高频操作时频繁重置 timer
        guard now.timeIntervalSince(lastUpdateTime) > 1 else { return }

        lastUpdateTime = now
        lastActiveTime = now
        saveLastActiveTime()
        resetTimer()

        #if DEBUG
        print("[AutoLockManager] Activity updated at \(now)")
        #endif
    }

    /// Lock the wallet
    func lock() {
        guard !isLocked else { return }

        isLocked = true
        print("[AutoLockManager] 🔒 Wallet locked due to inactivity")

        // Clear sensitive data from memory
        clearSensitiveData()
    }

    /// Unlock the wallet with biometrics or password
    func unlock(password: String? = nil) async throws {
        if BiometricAuthManager.shared.isBiometricEnabled {
            // Try biometric authentication
            let context = LAContext()
            var error: NSError?

            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                let reason = "Unlock Rabby Wallet"

                do {
                    let success = try await context.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: reason
                    )

                    if success {
                        isLocked = false
                        updateActivity()
                        print("[AutoLockManager] 🔓 Unlocked with biometrics")
                        return
                    }
                } catch {
                    throw AutoLockError.biometricsFailed
                }
            }
        }

        // Fallback to password
        if let password = password {
            let valid = try await KeyringManager.shared.verifyPassword(password)
            if valid {
                isLocked = false
                updateActivity()
                print("[AutoLockManager] 🔓 Unlocked with password")
            } else {
                throw AutoLockError.invalidPassword
            }
        } else {
            throw AutoLockError.authenticationRequired
        }
    }

    /// Set auto-lock enabled
    func setEnabled(_ enabled: Bool) {
        autoLockEnabled = enabled
        saveSettings()

        if !enabled {
            timer?.invalidate()
            timer = nil
            print("[AutoLockManager] Auto-lock disabled")
        } else {
            resetTimer()
            print("[AutoLockManager] Auto-lock enabled with duration \(autoLockDuration)s")
        }
    }

    /// Set auto-lock duration
    func setDuration(_ duration: TimeInterval) {
        autoLockDuration = duration
        saveSettings()

        // Restart timer with new duration
        timer?.invalidate()
        if autoLockEnabled && duration > 0 {
            resetTimer()
            print("[AutoLockManager] Auto-lock duration set to \(duration)s")
        }
    }

    // MARK: - Private Methods

    /// Reset timer to trigger lock after configured duration
    private func resetTimer() {
        timer?.invalidate()

        guard autoLockEnabled && autoLockDuration > 0 else { return }

        // ✅ 精确定时：在 duration 后触发锁定（单次触发，不重复）
        timer = Timer.scheduledTimer(
            withTimeInterval: autoLockDuration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }

        #if DEBUG
        print("[AutoLockManager] Timer reset: will lock in \(autoLockDuration)s")
        #endif
    }

    private func startTimer() {
        resetTimer()
    }

    /// Check if should lock (used when returning from background)
    private func checkAndLock() {
        guard autoLockEnabled && autoLockDuration > 0 else { return }

        let inactiveTime = Date().timeIntervalSince(lastActiveTime)

        #if DEBUG
        print("[AutoLockManager] checkAndLock: inactiveTime = \(inactiveTime)s, threshold = \(autoLockDuration)s")
        #endif

        if inactiveTime >= autoLockDuration && !isLocked {
            lock()
        }
    }

    private func loadSettings() {
        if let data = storage.getData(forKey: lockKey),
           let settings = try? JSONDecoder().decode(LockSettings.self, from: data) {
            self.autoLockEnabled = settings.enabled
            self.autoLockDuration = settings.duration
            print("[AutoLockManager] Settings loaded: enabled=\(settings.enabled), duration=\(settings.duration)s")
        }
    }

    private func saveSettings() {
        let settings = LockSettings(
            enabled: autoLockEnabled,
            duration: autoLockDuration
        )
        if let data = try? JSONEncoder().encode(settings) {
            storage.setData(data, forKey: lockKey)
        }
    }

    /// 持久化 lastActiveTime（用于应用重启后恢复）
    private func saveLastActiveTime() {
        UserDefaults.standard.set(lastActiveTime.timeIntervalSince1970, forKey: lastActiveTimeKey)
    }

    /// 加载 lastActiveTime（应用启动时恢复）
    private func loadLastActiveTime() {
        if let savedTime = UserDefaults.standard.object(forKey: lastActiveTimeKey) as? TimeInterval {
            lastActiveTime = Date(timeIntervalSince1970: savedTime)
            print("[AutoLockManager] Restored lastActiveTime: \(lastActiveTime)")
        }
    }

    private func clearSensitiveData() {
        // Clear keyrings from memory on auto-lock for security.
        // The vault in Keychain is NEVER touched — only in-memory state is cleared.
        // User must re-enter password to decrypt the vault again on next unlock.
        Task { @MainActor in
            await KeyringManager.shared.setLocked()
        }
    }

    /// Called when app enters background
    func appDidEnterBackground() {
        // ✅ 修复：记录进入后台的时间，但不修改 lastActiveTime
        backgroundTime = Date()
        saveLastActiveTime()  // 持久化当前的 lastActiveTime

        print("[AutoLockManager] 📱 App entered background at \(backgroundTime!)")
        print("[AutoLockManager] Last active time: \(lastActiveTime)")

        // 可选：如果需要最高安全性，可以立即锁定
        // lock()
    }

    /// Called when app enters foreground
    func appWillEnterForeground() {
        guard let backgroundTime = backgroundTime else {
            // 没有记录后台时间（可能是首次启动），直接检查
            checkAndLock()
            return
        }

        let backgroundDuration = Date().timeIntervalSince(backgroundTime)
        let totalInactiveTime = Date().timeIntervalSince(lastActiveTime)

        print("[AutoLockManager] 📱 App entering foreground")
        print("[AutoLockManager] Background duration: \(backgroundDuration)s")
        print("[AutoLockManager] Total inactive time: \(totalInactiveTime)s")
        print("[AutoLockManager] Lock threshold: \(autoLockDuration)s")

        // ✅ 如果总不活动时间超过设定，立即锁定
        if autoLockEnabled && autoLockDuration > 0 && totalInactiveTime >= autoLockDuration {
            lock()
        } else if autoLockEnabled && autoLockDuration > 0 {
            // ✅ 重新启动定时器（减去已过去的时间）
            let remainingTime = max(0, autoLockDuration - totalInactiveTime)
            if remainingTime > 0 {
                timer?.invalidate()
                timer = Timer.scheduledTimer(
                    withTimeInterval: remainingTime,
                    repeats: false
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.lock()
                    }
                }
                print("[AutoLockManager] Timer restarted: will lock in \(remainingTime)s")
            }
        }

        self.backgroundTime = nil
    }

    /// Called when app becomes active (for RabbyMobileApp integration)
    func appDidBecomeActive() {
        // 回到前台时先检查，再更新活动
        checkAndLock()
        if !isLocked {
            updateActivity()
        }
    }
}

// MARK: - Errors

enum AutoLockError: Error, LocalizedError {
    case biometricsFailed
    case invalidPassword
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .biometricsFailed:
            return "Biometric authentication failed"
        case .invalidPassword:
            return "Invalid password"
        case .authenticationRequired:
            return "Authentication required to unlock"
        }
    }
}
