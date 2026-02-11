import SwiftUI
import UIKit

/// Root view that handles wallet state (locked/unlocked)
struct RootView: View {
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
                            Text("Rabby Wallet")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    )
                    .transition(.opacity)
            }
        }
        .onAppear {
            checkBiometricAuth()
            setupScreenshotProtection()
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
                    let success = try await biometricManager.authenticate(
                        reason: "Unlock Rabby Wallet"
                    )
                    if success, let password = biometricManager.getBiometricPassword() {
                        try await keyringManager.submitPassword(password)
                    }
                } catch {
                    print("Biometric auth failed: \(error)")
                }
            }
        }
    }
    
    private func setupScreenshotProtection() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil, queue: .main
        ) { _ in
            // Show warning when screenshot is taken
            withAnimation { showScreenshotProtection = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showScreenshotProtection = false }
            }
        }
        
        // Hide content when entering app switcher
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { _ in
            withAnimation { showScreenshotProtection = true }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { _ in
            withAnimation { showScreenshotProtection = false }
        }
    }
}

/// Onboarding view for new users
struct OnboardingView: View {
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
                        title: "Welcome to Rabby",
                        subtitle: "The game-changing wallet for Ethereum and all EVM chains",
                        color: .blue
                    ).tag(0)
                    
                    onboardingPage(
                        icon: "shield.checkered",
                        title: "Pre-Sign Protection",
                        subtitle: "Every transaction is checked for risks before you sign",
                        color: .green
                    ).tag(1)
                    
                    onboardingPage(
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        title: "Multi-Chain Ready",
                        subtitle: "Seamlessly swap, bridge, and manage assets across chains",
                        color: .purple
                    ).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: .infinity)
                
                // Buttons
                VStack(spacing: 16) {
                    Button(action: { showCreateWallet = true }) {
                        Text("Create New Wallet")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("Create a new wallet")
                    .accessibilityHint("Generates a new seed phrase and wallet")
                    
                    Button(action: { showImportWallet = true }) {
                        Text("Import Wallet")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("Import existing wallet")
                    .accessibilityHint("Import using seed phrase or private key")
                    
                    Button(action: { /* Watch-only */ }) {
                        Text("Watch Address")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Add watch-only address")
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
    @StateObject private var keyringManager = KeyringManager.shared
    @StateObject private var biometricManager = BiometricAuthManager.shared
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showForgotPassword = false
    @State private var isUnlocking = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("Unlock Wallet")
                .font(.title)
                .fontWeight(.bold)
            
            // Password input
            SecureField("Enter password", text: $password)
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
                    Text(isUnlocking ? "Unlocking..." : "Unlock")
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
                        Text("Unlock with \(biometricManager.biometricType == .faceID ? "Face ID" : "Touch ID")")
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Forgot password
            Button(action: { showForgotPassword = true }) {
                Text("Forgot Password?")
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
        isUnlocking = true
        errorMessage = ""
        Task {
            do {
                try await keyringManager.submitPassword(password)
            } catch {
                withAnimation { errorMessage = "Incorrect password" }
                // Haptic feedback for error
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
            isUnlocking = false
        }
    }
    
    private func unlockWithBiometric() {
        Task {
            do {
                let success = try await biometricManager.authenticate(
                    reason: "Unlock Rabby Wallet"
                )
                if success, let savedPassword = biometricManager.getBiometricPassword() {
                    try await keyringManager.submitPassword(savedPassword)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Main tab view
struct MainTabView: View {
    var body: some View {
        TabView {
            AssetsView()
                .tabItem {
                    Image(systemName: "dollarsign.circle.fill")
                    Text("Assets")
                }
            
            SwapView()
                .tabItem {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    Text("Swap")
                }
            
            DAppBrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("DApps")
                }
            
            TransactionHistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
    }
}

// MARK: - ForgotPasswordView is defined in MiscViews.swift

// MARK: - Preview

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
