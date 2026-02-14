import Foundation
import LocalAuthentication

/// Biometric authentication manager for Face ID / Touch ID
@MainActor
class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    @Published var isBiometricEnabled: Bool = false
    @Published var canUseBiometric: Bool = false
    
    private let storageManager = StorageManager.shared
    
    private init() {
        isBiometricEnabled = storageManager.isBiometricEnabled()
        canUseBiometric = isBiometricAvailable()
    }
    
    /// Computed property for biometric type (used by views)
    var biometricType: BiometricType {
        let context = LAContext()
        guard isBiometricAvailable() else { return .none }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        case .none: return .none
        @unknown default: return .unknown
        }
    }
    
    // MARK: - Biometric Availability
    
    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // MARK: - Authentication
    
    func authenticate(reason: String = "Authenticate to access your wallet") async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Password"
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: true)
                } else if let error = error {
                    continuation.resume(throwing: BiometricError.authenticationFailed(error.localizedDescription))
                } else {
                    continuation.resume(throwing: BiometricError.unknown)
                }
            }
        }
    }
    
    func authenticateWithPasscode(reason: String = "Authenticate to access your wallet") async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: true)
                } else if let error = error {
                    continuation.resume(throwing: BiometricError.authenticationFailed(error.localizedDescription))
                } else {
                    continuation.resume(throwing: BiometricError.unknown)
                }
            }
        }
    }
    
    // MARK: - Biometric Settings
    
    func enableBiometric() {
        storageManager.saveBiometricEnabled(true)
        isBiometricEnabled = true
    }
    
    func disableBiometric() {
        storageManager.saveBiometricEnabled(false)
        isBiometricEnabled = false
        try? deleteBiometricPassword()
    }
    
    // MARK: - Password Storage with Biometric
    
    func saveBiometricPassword(_ password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw BiometricError.invalidPassword
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.rabby.wallet.biometric",
            kSecAttrAccount as String: "walletPassword",
            kSecValueData as String: passwordData,
            kSecAttrAccessControl as String: createAccessControl()
        ]
        
        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.rabby.wallet.biometric",
            kSecAttrAccount as String: "walletPassword"
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw BiometricError.keychainError(status)
        }
    }
    
    /// Synchronous password getter for use in non-async contexts (returns nil if not stored)
    func getBiometricPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.rabby.wallet.biometric",
            kSecAttrAccount as String: "walletPassword",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }
    
    /// Async password getter with biometric prompt
    func getBiometricPasswordAsync() async throws -> String {
        let context = LAContext()
        context.localizedReason = "Authenticate to unlock wallet"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.rabby.wallet.biometric",
            kSecAttrAccount as String: "walletPassword",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw BiometricError.passwordNotStored
            }
            throw BiometricError.keychainError(status)
        }
        
        guard let passwordData = result as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw BiometricError.invalidPassword
        }
        
        return password
    }
    
    func deleteBiometricPassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.rabby.wallet.biometric",
            kSecAttrAccount as String: "walletPassword"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BiometricError.keychainError(status)
        }
    }
    
    private func createAccessControl() -> SecAccessControl {
        var error: Unmanaged<CFError>?
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        )
        
        if let error = error {
            print("Failed to create access control: \(error.takeRetainedValue())")
        }
        
        return access!
    }
    
    // MARK: - Quick Unlock
    
    func unlockWallet() async throws {
        guard isBiometricEnabled else {
            throw BiometricError.biometricNotEnabled
        }
        
        let password = try await getBiometricPasswordAsync()
        try await KeyringManager.shared.submitPassword(password)
    }
}

// MARK: - Biometric Type

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    case unknown
    
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        case .unknown:
            return "Biometric"
        }
    }
    
    var icon: String {
        switch self {
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        default:
            return "lock.shield"
        }
    }
}

// MARK: - Errors

enum BiometricError: Error, LocalizedError {
    case authenticationFailed(String)
    case biometricNotAvailable
    case biometricNotEnabled
    case invalidPassword
    case passwordNotStored
    case keychainError(OSStatus)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricNotEnabled:
            return "Biometric authentication is not enabled"
        case .invalidPassword:
            return "Invalid password format"
        case .passwordNotStored:
            return "Password not stored for biometric authentication"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .unknown:
            return "Unknown biometric error"
        }
    }
}

// MARK: - AutoLockManager is defined in AutoLockManager.swift
