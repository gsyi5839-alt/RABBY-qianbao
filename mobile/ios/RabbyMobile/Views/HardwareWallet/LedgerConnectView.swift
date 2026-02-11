import SwiftUI

/// Ledger Hardware Wallet Connection View
struct LedgerConnectView: View {
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDevice: BluetoothManager.HardwareDevice?
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var accountsToAdd = 1
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Bluetooth Status
                bluetoothStatusSection
                
                // Device List
                if bluetoothManager.connectionState == .disconnected {
                    deviceListSection
                } else {
                    connectedDeviceSection
                }
                
                Spacer()
                
                // Action Button
                actionButtonSection
            }
            .navigationTitle("Connect Ledger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Ledger Icon
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Connect your Ledger")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Make sure your Ledger is unlocked and the Ethereum app is open")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 32)
        .padding(.bottom, 24)
    }
    
    // MARK: - Bluetooth Status
    
    private var bluetoothStatusSection: some View {
        HStack {
            Image(systemName: bluetoothStatusIcon)
                .foregroundColor(bluetoothStatusColor)
            
            Text(bluetoothStatusText)
                .font(.caption)
                .foregroundColor(bluetoothStatusColor)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var bluetoothStatusIcon: String {
        switch bluetoothManager.bluetoothState {
        case .poweredOn:
            return "checkmark.circle.fill"
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
            return .green
        case .poweredOff, .unauthorized:
            return .red
        default:
            return .orange
        }
    }
    
    private var bluetoothStatusText: String {
        switch bluetoothManager.bluetoothState {
        case .poweredOn:
            return "Bluetooth is ready"
        case .poweredOff:
            return "Please turn on Bluetooth"
        case .unauthorized:
            return "Bluetooth access not authorized"
        default:
            return "Checking Bluetooth status..."
        }
    }
    
    // MARK: - Device List Section
    
    private var deviceListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Devices")
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
                    VStack(spacing: 12) {
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
            
            Text("No devices found")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Make sure your Ledger is nearby and Bluetooth is enabled")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { bluetoothManager.startScanning() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Scan Again")
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
        VStack(spacing: 20) {
            // Connected status
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top, 20)
            
            // Device info
            if let device = bluetoothManager.connectedDevice {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.blue)
                        Text(device.name)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Ready to import accounts")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Account count selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Number of accounts to import")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Stepper("\(accountsToAdd) account(s)", value: $accountsToAdd, in: 1...10)
                    .font(.body)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Action Button
    
    private var actionButtonSection: some View {
        VStack(spacing: 12) {
            if bluetoothManager.connectionState == .disconnected {
                // Scan or Connect button
                if bluetoothManager.isScanning {
                    Button(action: { bluetoothManager.stopScanning() }) {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Scanning...")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(true)
                } else if let device = selectedDevice {
                    Button(action: { connectToDevice(device) }) {
                        Text("Connect to \(device.name)")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: { bluetoothManager.startScanning() }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Scan for Devices").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(bluetoothManager.bluetoothState != .poweredOn)
                }
            } else {
                // Import accounts button
                Button(action: { importAccounts() }) {
                    if isConnecting {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Importing...")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    } else {
                        Text("Import Accounts")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .disabled(isConnecting)
                
                Button(action: { bluetoothManager.disconnect() }) {
                    Text("Disconnect")
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
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func connectToDevice(_ device: BluetoothManager.HardwareDevice) {
        bluetoothManager.connect(to: device)
    }
    
    private func importAccounts() {
        isConnecting = true
        
        Task {
            do {
                let ledgerKeyring = LedgerKeyring()
                let accounts = try await ledgerKeyring.addAccounts(count: accountsToAdd)
                
                await keyringManager.addKeyring(ledgerKeyring)
                
                await MainActor.run {
                    isConnecting = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: BluetoothManager.HardwareDevice
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Device icon
                Image(systemName: deviceIcon)
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                // Device info
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(deviceTypeText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
                
                // Signal strength
                signalStrengthIcon
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
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
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var deviceTypeText: String {
        switch device.type {
        case .ledgerNanoX:
            return "Ledger Nano X"
        case .ledgerNanoSPlus:
            return "Ledger Nano S Plus"
        case .unknown:
            return "Hardware Wallet"
        }
    }
    
    private var signalStrengthIcon: some View {
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
