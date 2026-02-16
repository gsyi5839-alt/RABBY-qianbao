import SwiftUI
import UIKit

/// Root view that handles wallet state (locked/unlocked)
struct RootView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var biometricManager = BiometricAuthManager.shared
    @StateObject private var autoLock = AutoLockManager.shared
    @State private var showOnboarding = false
    @State private var isCheckingAuth = true
    @State private var showScreenshotProtection = false
    
    var body: some View {
        ZStack {
            Group {
                if isCheckingAuth {
                    // Splash / loading state
                    VStack(spacing: 20) {
                        Image(systemName: "wallet.pass.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.blue)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else if !keyringManager.isInitialized {
                    OnboardingView()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else if keyringManager.isUnlocked && !autoLock.isLocked {
                    MainTabView()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            autoLock.updateActivity()
                        }
                } else {
                    UnlockView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: keyringManager.isInitialized)
            .animation(.easeInOut(duration: 0.35), value: keyringManager.isUnlocked)
            .animation(.easeInOut(duration: 0.35), value: autoLock.isLocked)
            
            // Screenshot protection overlay
            if showScreenshotProtection {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            Text(localization.t("app_name", defaultValue: "Rabby Wallet"))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    )
                    .transition(.opacity)
            }
        }
        .onAppear {
            checkBiometricAuth()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            // Show warning when screenshot is taken
            withAnimation { showScreenshotProtection = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showScreenshotProtection = false }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Hide content only when app really enters background
            withAnimation { showScreenshotProtection = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            withAnimation { showScreenshotProtection = false }
        }
    }
    
    private func checkBiometricAuth() {
        // Brief delay to show splash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { isCheckingAuth = false }
        }
        if biometricManager.isBiometricEnabled && biometricManager.canUseBiometric {
            Task {
                do {
                    try await biometricManager.unlockWallet()
                    await MainActor.run {
                        autoLock.isLocked = false
                        autoLock.updateActivity()
                    }
                } catch {
                    print("Biometric auth failed: \(error)")
                }
            }
        }
    }
    
}

/// Onboarding view for new users
struct OnboardingView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @State private var showCreateWallet = false
    @State private var showImportWallet = false
    @State private var currentPage = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Feature pages
                TabView(selection: $currentPage) {
                    onboardingPage(
                        icon: "wallet.pass.fill",
                        title: localization.t("welcome_title", defaultValue: "Welcome to Rabby"),
                        subtitle: localization.t("welcome_subtitle", defaultValue: "The game-changing wallet for Ethereum and all EVM chains"),
                        color: .blue
                    ).tag(0)
                    
                    onboardingPage(
                        icon: "shield.checkered",
                        title: localization.t("onboarding_security_title", defaultValue: "Pre-Sign Protection"),
                        subtitle: localization.t("onboarding_security_subtitle", defaultValue: "Every transaction is checked for risks before you sign"),
                        color: .green
                    ).tag(1)
                    
                    onboardingPage(
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        title: localization.t("onboarding_multichain_title", defaultValue: "Multi-Chain Ready"),
                        subtitle: localization.t("onboarding_multichain_subtitle", defaultValue: "Seamlessly swap, bridge, and manage assets across chains"),
                        color: .purple
                    ).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: .infinity)
                
                // Buttons
                VStack(spacing: 16) {
                    Button(action: { showCreateWallet = true }) {
                        Text(localization.t("create_wallet", defaultValue: "Create New Wallet"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel(localization.t("create_wallet", defaultValue: "Create New Wallet"))
                    
                    Button(action: { showImportWallet = true }) {
                        Text(localization.t("import_wallet", defaultValue: "Import Wallet"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel(localization.t("import_wallet", defaultValue: "Import Wallet"))
                    
                    Button(action: { /* Watch-only */ }) {
                        Text(localization.t("watch_address", defaultValue: "Watch Address"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(localization.t("watch_address", defaultValue: "Watch Address"))
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            .sheet(isPresented: $showCreateWallet) {
                CreateWalletView()
            }
            .sheet(isPresented: $showImportWallet) {
                ImportWalletView()
            }
        }
    }
    
    private func onboardingPage(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 10)
            
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
}

/// Unlock view for existing users
struct UnlockView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var biometricManager = BiometricAuthManager.shared
    @StateObject private var autoLock = AutoLockManager.shared
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showForgotPassword = false
    @State private var isUnlocking = false
    @State private var failedAttempts = 0
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text(localization.t("unlock_wallet", defaultValue: "Unlock Wallet"))
                .font(.title)
                .fontWeight(.bold)
            
            // Password input
            SecureField(localization.t("enter_password", defaultValue: "Enter password"), text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 30)
                .autocapitalization(.none)
                .onSubmit { unlock() }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
            
            // Unlock button
            Button(action: unlock) {
                HStack {
                    if isUnlocking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isUnlocking ? localization.t("unlocking", defaultValue: "Unlocking...") : localization.t("unlock", defaultValue: "Unlock"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(password.isEmpty || isUnlocking ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(password.isEmpty || isUnlocking)
            .padding(.horizontal, 30)
            
            // Biometric unlock
            if biometricManager.isBiometricEnabled && biometricManager.canUseBiometric {
                Button(action: unlockWithBiometric) {
                    HStack {
                        Image(systemName: biometricManager.biometricType == .faceID ? "faceid" : "touchid")
                        Text(biometricManager.biometricType == .faceID
                             ? localization.t("unlock_with_face_id", defaultValue: "Unlock with Face ID")
                             : localization.t("unlock_with_touch_id", defaultValue: "Unlock with Touch ID"))
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Forgot password
            Button(action: { showForgotPassword = true }) {
                Text(localization.t("forgot_password", defaultValue: "Forgot Password?"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }
    
    private func unlock() {
        guard !isUnlocking else { return }
        isUnlocking = true
        errorMessage = ""
        let inputPassword = password

        Task {
            do {
                try await keyringManager.submitPassword(inputPassword)
                if biometricManager.isBiometricEnabled {
                    try? biometricManager.saveBiometricPassword(inputPassword)
                }
                // Success — MUST also reset autoLock state, otherwise
                // RootView's condition `isUnlocked && !autoLock.isLocked`
                // remains false and the user is stuck on this screen forever.
                await MainActor.run {
                    autoLock.isLocked = false
                    autoLock.updateActivity()
                    isUnlocking = false
                    failedAttempts = 0
                    password = ""
                }
            } catch let error as KeyringError where error == .invalidPassword {
                await MainActor.run {
                    failedAttempts += 1
                    withAnimation {
                        if failedAttempts >= 5 {
                            errorMessage = localization.t("too_many_attempts",
                                defaultValue: "Too many failed attempts. Use \"Forgot Password\" to reset with your recovery phrase.")
                        } else {
                            errorMessage = localization.t("incorrect_password",
                                defaultValue: "Incorrect password")
                        }
                        isUnlocking = false
                    }
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    password = ""
                }
            } catch {
                // Non-password error (vault corrupted, deserialization failure, etc.)
                NSLog("[UnlockView] Unlock error (not password): %@", "\(error)")
                await MainActor.run {
                    withAnimation {
                        errorMessage = localization.t("unlock_error",
                            defaultValue: "Unlock failed: \(error.localizedDescription)")
                        isUnlocking = false
                    }
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    password = ""
                }
            }
        }
    }
    
    private func unlockWithBiometric() {
        Task {
            do {
                try await biometricManager.unlockWallet()
                // Also reset autoLock — same fix as password unlock
                await MainActor.run {
                    autoLock.isLocked = false
                    autoLock.updateActivity()
                    failedAttempts = 0
                    errorMessage = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/// Main tab view
struct MainTabView: View {
    @EnvironmentObject private var localization: LocalizationManager
    var body: some View {
        TabView {
            AssetsView()
                .tabItem {
                    Image(systemName: "dollarsign.circle.fill")
                    Text(localization.t("tab_assets", defaultValue: "Assets"))
                }
            
            SwapView()
                .tabItem {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    Text(localization.t("tab_swap", defaultValue: "Swap"))
                }
            
            DAppBrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text(localization.t("tab_dapps", defaultValue: "DApps"))
                }
            
            TransactionHistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text(localization.t("tab_history", defaultValue: "History"))
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text(localization.t("tab_settings", defaultValue: "Settings"))
                }
        }
    }
}

// MARK: - ForgotPasswordView is defined in MiscViews.swift

// MARK: - Preview

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(LocalizationManager.shared)
    }
}
