import Foundation
import Combine
import LocalAuthentication
import UIKit

/// Auto Lock Manager - Auto-lock wallet after inactivity
/// Equivalent to Web version's autoLock service
@MainActor
class AutoLockManager: ObservableObject {
    static let shared = AutoLockManager()
    
    @Published var isLocked = false
    @Published var autoLockEnabled = true
    @Published var autoLockDuration: TimeInterval = 3600 // 1 hour default
    
    private var lastActiveTime: Date = Date()
    private var timer: Timer?
    
    private let storage = StorageManager.shared
    private let lockKey = "rabby_auto_lock_settings"
    
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
    
    private init() {
        loadSettings()
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
    }
    
    deinit {
        timer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    // MARK: - Public Methods
    
    /// Update last active time
    func updateActivity() {
        lastActiveTime = Date()
    }
    
    /// Lock the wallet
    func lock() {
        isLocked = true
        // Clear sensitive data from memory
        clearSensitiveData()
    }
    
    /// Unlock the wallet with biometrics or password
    func unlock(password: String? = nil) async throws {
        if KeyringManager.shared.biometricsEnabled {
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
        } else {
            startTimer()
        }
    }
    
    /// Set auto-lock duration
    func setDuration(_ duration: TimeInterval) {
        autoLockDuration = duration
        saveSettings()
        
        // Restart timer with new duration
        timer?.invalidate()
        if autoLockEnabled && duration > 0 {
            startTimer()
        }
    }
    
    /// Check if should lock
    func checkAndLock() {
        guard autoLockEnabled && autoLockDuration > 0 else { return }
        
        let inactiveTime = Date().timeIntervalSince(lastActiveTime)
        if inactiveTime >= autoLockDuration && !isLocked {
            lock()
        }
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        guard autoLockEnabled && autoLockDuration > 0 else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndLock()
            }
        }
    }
    
    private func loadSettings() {
        if let data = storage.getData(forKey: lockKey),
           let settings = try? JSONDecoder().decode(LockSettings.self, from: data) {
            self.autoLockEnabled = settings.enabled
            self.autoLockDuration = settings.duration
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
    
    private func clearSensitiveData() {
        // Clear cached sensitive data
        // KeyringManager will handle keychain data
    }
    
    /// Called when app enters background
    func appDidEnterBackground() {
        // Record time when app goes to background
        lastActiveTime = Date()
    }
    
    /// Called when app enters foreground
    func appWillEnterForeground() {
        // Check if should lock when app returns to foreground
        checkAndLock()
    }
    
    /// Called when app becomes active (for RabbyMobileApp integration)
    func appDidBecomeActive() {
        checkAndLock()
        updateActivity()
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
