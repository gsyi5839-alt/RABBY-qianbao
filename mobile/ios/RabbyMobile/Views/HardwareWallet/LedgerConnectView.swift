import SwiftUI

/// Ledger Hardware Wallet Connection & Account Management View
///
/// Provides a complete flow for:
/// 1. Scanning for nearby Ledger devices via BLE
/// 2. Connecting to a selected device
/// 3. Verifying the Ethereum app is open
/// 4. Importing accounts from the Ledger
/// 5. Displaying imported addresses
/// 6. Showing signing-in-progress overlay when the Ledger is signing
///
/// This view works in conjunction with `BluetoothManager` (BLE transport)
/// and `LedgerKeyring` (APDU protocol + Keyring interface).
struct LedgerConnectView: View {
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedDevice: BluetoothManager.LedgerDevice?
    @State private var isConnecting = false
    @State private var isVerifyingApp = false
    @State private var isImporting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var errorTitle = "Error"
    @State private var accountsToAdd = 1
    @State private var importedAccounts: [String] = []
    @State private var appInfo: (name: String, version: String)?
    @State private var showSuccessAnimation = false

    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                VStack(spacing: 0) {
                    headerSection
                    bluetoothStatusSection
                    mainContentSection
                    Spacer()
                    actionButtonSection
                }

                // Signing overlay
                if bluetoothManager.isSigning {
                    signingOverlay
                }

                // Connection progress overlay
                if isConnecting || isVerifyingApp {
                    connectionProgressOverlay
                }
            }
            .navigationTitle(L("Connect Ledger"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bluetoothManager.connectionState == .connected && !importedAccounts.isEmpty {
                        Button(L("Done")) {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.body.weight(.semibold))
                    }
                }
            }
            .alert(errorTitle, isPresented: $showError) {
                Button(L("OK"), role: .cancel) { }
                if errorTitle == "Ethereum App Required" {
                    Button(L("Retry")) {
                        Task { await verifyEthApp() }
                    }
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Ledger icon with connection-state-dependent styling
            ZStack {
                Circle()
                    .fill(headerIconBackgroundColor)
                    .frame(width: 100, height: 100)

                Image(systemName: headerIconName)
                    .font(.system(size: 44))
                    .foregroundColor(headerIconColor)
            }

            Text(headerTitle)
                .font(.title2)
                .fontWeight(.bold)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private var headerIconName: String {
        switch bluetoothManager.connectionState {
        case .connected:
            return "checkmark.shield.fill"
        case .connecting, .discoveringServices:
            return "lock.shield"
        default:
            return "lock.shield"
        }
    }

    private var headerIconColor: Color {
        switch bluetoothManager.connectionState {
        case .connected:
            return .white
        default:
            return .blue
        }
    }

    private var headerIconBackgroundColor: Color {
        switch bluetoothManager.connectionState {
        case .connected:
            return .green
        default:
            return .blue.opacity(0.1)
        }
    }

    private var headerTitle: String {
        switch bluetoothManager.connectionState {
        case .connected:
            if !importedAccounts.isEmpty {
                return LocalizationManager.shared.t("Accounts Imported")
            }
            return LocalizationManager.shared.t("Ledger Connected")
        case .connecting, .discoveringServices:
            return LocalizationManager.shared.t("Connecting...")
        case .scanning:
            return LocalizationManager.shared.t("Searching for Ledger")
        default:
            return LocalizationManager.shared.t("Connect your Ledger")
        }
    }

    private var headerSubtitle: String {
        switch bluetoothManager.connectionState {
        case .connected:
            if let info = appInfo {
                return LocalizationManager.shared.t("ios.ledger.ethAppRunning", args: ["version": info.version])
            }
            if !importedAccounts.isEmpty {
                return LocalizationManager.shared.t("ios.ledger.accountsReady", args: ["count": "\(importedAccounts.count)"])
            }
            return LocalizationManager.shared.t("Ready to import accounts")
        case .connecting, .discoveringServices:
            return LocalizationManager.shared.t("Please wait while we connect to your device")
        case .scanning:
            return LocalizationManager.shared.t("Make sure your Ledger is unlocked and nearby")
        default:
            return LocalizationManager.shared.t("Make sure your Ledger is unlocked and the Ethereum app is open")
        }
    }

    // MARK: - Bluetooth Status

    private var bluetoothStatusSection: some View {
        HStack(spacing: 8) {
            Image(systemName: bluetoothStatusIcon)
                .foregroundColor(bluetoothStatusColor)
                .font(.system(size: 14))

            Text(bluetoothStatusText)
                .font(.caption)
                .foregroundColor(bluetoothStatusColor)

            Spacer()

            if bluetoothManager.connectionState == .connected,
               let device = bluetoothManager.connectedDevice {
                Text(device.type.rawValue)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }

    private var bluetoothStatusIcon: String {
        switch bluetoothManager.bluetoothState {
        case .poweredOn:
            if bluetoothManager.connectionState == .connected {
                return "checkmark.circle.fill"
            }
            return "antenna.radiowaves.left.and.right"
        case .poweredOff:
            return "xmark.circle.fill"
        case .unauthorized:
            return "exclamationmark.triangle.fill"
        default:
            return "questionmark.circle"
        }
    }

    private var bluetoothStatusColor: Color {
        switch bluetoothManager.bluetoothState {
        case .poweredOn:
            if bluetoothManager.connectionState == .connected {
                return .green
            }
            return .blue
        case .poweredOff, .unauthorized:
            return .red
        default:
            return .orange
        }
    }

    private var bluetoothStatusText: String {
        switch bluetoothManager.bluetoothState {
        case .poweredOn:
            switch bluetoothManager.connectionState {
            case .connected:
                return LocalizationManager.shared.t("Connected via Bluetooth")
            case .connecting, .discoveringServices:
                return LocalizationManager.shared.t("Connecting...")
            case .scanning:
                return LocalizationManager.shared.t("Scanning for devices...")
            default:
                return LocalizationManager.shared.t("Bluetooth is ready")
            }
        case .poweredOff:
            return LocalizationManager.shared.t("Please turn on Bluetooth")
        case .unauthorized:
            return LocalizationManager.shared.t("Bluetooth access not authorized")
        default:
            return LocalizationManager.shared.t("Checking Bluetooth status...")
        }
    }

    // MARK: - Main Content (State-Driven)

    @ViewBuilder
    private var mainContentSection: some View {
        switch bluetoothManager.connectionState {
        case .disconnected:
            deviceListSection
        case .scanning:
            scanningSection
        case .connecting, .discoveringServices:
            connectingSection
        case .connected:
            connectedDeviceSection
        case .disconnecting:
            VStack {
                ProgressView(L("Disconnecting..."))
                    .padding()
            }
        }
    }

    // MARK: - Scanning Section

    private var scanningSection: some View {
        VStack(spacing: 16) {
            // Animated scanning indicator
            HStack {
                Text(L("Searching for Ledger devices"))
                    .font(.headline)
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
            }
            .padding(.horizontal)
            .padding(.top, 20)

            // Scanning animation
            ScanningAnimationView()
                .frame(height: 80)
                .padding(.horizontal)

            // Show any discovered devices immediately
            if !bluetoothManager.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Found Devices"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(bluetoothManager.discoveredDevices) { device in
                                DeviceRow(device: device, isSelected: selectedDevice?.id == device.id) {
                                    selectedDevice = device
                                    connectToDevice(device)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Connecting Section

    private var connectingSection: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            ProgressView()
                .scaleEffect(1.5)

            Text(L("Connecting to your Ledger..."))
                .font(.headline)

            Text(L("This may take a few seconds"))
                .font(.subheadline)
                .foregroundColor(.gray)

            if bluetoothManager.connectionState == .discoveringServices {
                Text(L("Discovering services..."))
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
    }

    // MARK: - Device List Section

    private var deviceListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Available Devices"))
                    .font(.headline)

                Spacer()

                if bluetoothManager.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)

            if bluetoothManager.discoveredDevices.isEmpty {
                emptyDeviceList
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(bluetoothManager.discoveredDevices) { device in
                            DeviceRow(device: device, isSelected: selectedDevice?.id == device.id) {
                                selectedDevice = device
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var emptyDeviceList: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(L("No devices found"))
                .font(.subheadline)
                .foregroundColor(.gray)

            Text(L("Make sure your Ledger is nearby and Bluetooth is enabled"))
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { bluetoothManager.startScanning() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(L("Scan Again"))
                }
                .font(.subheadline)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Connected Device Section

    private var connectedDeviceSection: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Device info card
                if let device = bluetoothManager.connectedDevice {
                    deviceInfoCard(device)
                }

                // App info card (if verified)
                if let info = appInfo {
                    appInfoCard(info)
                }

                // Imported accounts list
                if !importedAccounts.isEmpty {
                    importedAccountsList
                } else {
                    // Account count selector
                    accountCountSelector
                }
            }
            .padding(.top, 16)
        }
    }

    private func deviceInfoCard(_ device: BluetoothManager.LedgerDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 28))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.body)
                    .fontWeight(.semibold)

                Text(device.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func appInfoCard(_ info: (name: String, version: String)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "app.badge.checkmark.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(info.name) App")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(LocalizationManager.shared.t("ios.ledger.appVersion", args: ["version": info.version]))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var importedAccountsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Imported Accounts"))
                    .font(.headline)

                Spacer()

                Text("\(importedAccounts.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            ForEach(Array(importedAccounts.enumerated()), id: \.offset) { index, address in
                HStack(spacing: 12) {
                    // Account index badge
                    Text("\(index)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 28, height: 28)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(14)

                    // Address
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizationManager.shared.t("ios.ledger.accountIndex", args: ["index": "\(index)"]))
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text(formatAddress(address))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // Copy button
                    Button(action: {
                        UIPasteboard.general.string = address
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
    }

    private var accountCountSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Number of accounts to import"))
                .font(.subheadline)
                .foregroundColor(.gray)

            Stepper(LocalizationManager.shared.t("ios.ledger.accountCount", args: ["count": "\(accountsToAdd)"]), value: $accountsToAdd, in: 1...10)
                .font(.body)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Action Button

    private var actionButtonSection: some View {
        VStack(spacing: 12) {
            switch bluetoothManager.connectionState {
            case .disconnected:
                if bluetoothManager.isScanning {
                    // Stop scanning button
                    secondaryButton(title: LocalizationManager.shared.t("Stop Scanning"), icon: "stop.fill") {
                        bluetoothManager.stopScanning()
                    }
                } else if let device = selectedDevice {
                    // Connect button
                    primaryButton(title: LocalizationManager.shared.t("ios.ledger.connectTo", args: ["name": device.name])) {
                        connectToDevice(device)
                    }
                } else {
                    // Scan button
                    primaryButton(title: LocalizationManager.shared.t("Scan for Devices"), icon: "magnifyingglass") {
                        bluetoothManager.startScanning()
                    }
                    .disabled(bluetoothManager.bluetoothState != .poweredOn)
                }

            case .scanning:
                secondaryButton(title: LocalizationManager.shared.t("Stop Scanning"), icon: "stop.fill") {
                    bluetoothManager.stopScanning()
                }

            case .connecting, .discoveringServices:
                secondaryButton(title: LocalizationManager.shared.t("Cancel"), icon: nil) {
                    bluetoothManager.disconnect()
                }

            case .connected:
                if importedAccounts.isEmpty {
                    // Import accounts button
                    if isImporting {
                        loadingButton(title: LocalizationManager.shared.t("Importing Accounts..."))
                    } else {
                        primaryButton(title: LocalizationManager.shared.t("ios.ledger.importAccounts", args: ["count": "\(accountsToAdd)"])) {
                            importAccounts()
                        }
                    }
                } else {
                    // Add more accounts
                    primaryButton(title: LocalizationManager.shared.t("Import More Accounts")) {
                        importedAccounts.removeAll()
                    }
                }

                // Disconnect button
                Button(action: { bluetoothManager.disconnect() }) {
                    Text(L("Disconnect"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .foregroundColor(.red)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 1)
                        )
                }

            case .disconnecting:
                loadingButton(title: LocalizationManager.shared.t("Disconnecting..."))
            }
        }
        .padding()
    }

    // MARK: - Overlays

    private var signingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Pulsing Ledger icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .opacity(0.9)

                Text(L("Confirm on your Ledger"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(L("Please review and approve the transaction on your Ledger device"))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)

                Text(L("Do not disconnect your device"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5).opacity(0.95))
            )
            .padding(.horizontal, 40)
        }
    }

    private var connectionProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)

                Text(isVerifyingApp ? LocalizationManager.shared.t("Verifying Ethereum app...") : LocalizationManager.shared.t("Connecting..."))
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(isVerifyingApp
                     ? LocalizationManager.shared.t("Checking if the Ethereum app is open on your Ledger")
                     : LocalizationManager.shared.t("Establishing Bluetooth connection"))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 10)
            )
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Button Helpers

    private func primaryButton(title: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }

    private func secondaryButton(title: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
    }

    private func loadingButton(title: String) -> some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text(title)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func connectToDevice(_ device: BluetoothManager.LedgerDevice) {
        selectedDevice = device
        bluetoothManager.connect(to: device)

        // After connection, verify the Ethereum app
        Task {
            // Wait for connection to complete
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            if bluetoothManager.connectionState == .connected {
                await verifyEthApp()
            }
        }
    }

    private func verifyEthApp() async {
        isVerifyingApp = true
        defer { isVerifyingApp = false }

        do {
            let ledgerKeyring = LedgerKeyring()
            let info = try await ledgerKeyring.verifyEthereumApp()
            await MainActor.run {
                self.appInfo = (name: info.appName, version: info.version)
            }
        } catch let error as LedgerError {
            if case .ethereumAppNotOpen = error {
            await MainActor.run {
                errorTitle = LocalizationManager.shared.t("Ethereum App Required")
                errorMessage = LocalizationManager.shared.t("Please open the Ethereum app on your Ledger device and try again.")
                showError = true
                }
            } else {
                await MainActor.run {
                    errorTitle = LocalizationManager.shared.t("Ledger Error")
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } catch {
            await MainActor.run {
                errorTitle = LocalizationManager.shared.t("Verification Failed")
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func importAccounts() {
        isImporting = true

        Task {
            do {
                let ledgerKeyring = LedgerKeyring()
                let accounts = try await ledgerKeyring.addAccounts(count: accountsToAdd)

                await keyringManager.addKeyring(ledgerKeyring)

                await MainActor.run {
                    isImporting = false
                    importedAccounts = accounts
                }
            } catch let error as BluetoothError {
                await MainActor.run {
                    isImporting = false
                    errorTitle = LocalizationManager.shared.t("Import Failed")
                    errorMessage = error.localizedDescription
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorTitle = LocalizationManager.shared.t("Import Failed")
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        let start = address.prefix(8)
        let end = address.suffix(6)
        return "\(start)...\(end)"
    }
}

// MARK: - Scanning Animation View

/// Animated view that shows expanding concentric circles to indicate BLE scanning.
struct ScanningAnimationView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Expanding circles
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                    .scaleEffect(animate ? 1.0 + CGFloat(index) * 0.3 : 0.5)
                    .opacity(animate ? 0.0 : 0.6)
                    .animation(
                        Animation.easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5),
                        value: animate
                    )
            }

            // Center icon
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 24))
                .foregroundColor(.blue)
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: BluetoothManager.LedgerDevice
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Device icon
                Image(systemName: deviceIcon)
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                    .frame(width: 40)

                // Device info
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(device.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }

                // Signal strength
                signalStrengthView
            }
            .padding(14)
            .background(isSelected ? Color.blue.opacity(0.08) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }

    private var deviceIcon: String {
        switch device.type {
        case .ledgerNanoX:
            return "lock.shield.fill"
        case .ledgerNanoSPlus:
            return "lock.shield"
        case .ledgerStax:
            return "rectangle.portrait.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var signalStrengthView: some View {
        let rssi = device.rssi
        let bars: Int
        if rssi >= -50 {
            bars = 3
        } else if rssi >= -70 {
            bars = 2
        } else {
            bars = 1
        }

        return HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < bars ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + index * 3))
            }
        }
    }
}

// MARK: - Preview

struct LedgerConnectView_Previews: PreviewProvider {
    static var previews: some View {
        LedgerConnectView()
    }
}
