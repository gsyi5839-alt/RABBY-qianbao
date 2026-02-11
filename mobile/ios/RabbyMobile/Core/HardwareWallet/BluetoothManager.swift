import Foundation
import CoreBluetooth
import Combine

/// Bluetooth Manager for Hardware Wallet connections
/// Supports Ledger Nano X and other BLE-enabled hardware wallets
@MainActor
class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()
    
    // MARK: - Published Properties
    
    @Published var isScanning = false
    @Published var discoveredDevices: [HardwareDevice] = []
    @Published var connectedDevice: HardwareDevice?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var bluetoothState: CBManagerState = .unknown
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    // Ledger Nano X service and characteristic UUIDs
    private let ledgerServiceUUID = CBUUID(string: "13D63400-2C97-0004-0000-4C6564676572")
    private let ledgerWriteCharUUID = CBUUID(string: "13D63400-2C97-0004-0002-4C6564676572")
    private let ledgerNotifyCharUUID = CBUUID(string: "13D63400-2C97-0004-0001-4C6564676572")
    
    // Response buffer
    private var responseBuffer = Data()
    private var responseContinuation: CheckedContinuation<Data, Error>?
    
    // MARK: - Models
    
    struct HardwareDevice: Identifiable, Equatable {
        let id: UUID
        let name: String
        let type: DeviceType
        let rssi: Int
        var peripheral: CBPeripheral?
        
        enum DeviceType {
            case ledgerNanoX
            case ledgerNanoSPlus
            case unknown
        }
        
        static func == (lhs: HardwareDevice, rhs: HardwareDevice) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case disconnecting
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for hardware wallets
    func startScanning() {
        guard bluetoothState == .poweredOn else {
            print("❌ Bluetooth not powered on")
            return
        }
        
        discoveredDevices.removeAll()
        isScanning = true
        
        // Scan for Ledger devices
        centralManager.scanForPeripherals(
            withServices: [ledgerServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Auto stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }
    
    /// Stop scanning
    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }
    
    /// Connect to a hardware device
    func connect(to device: HardwareDevice) {
        guard let peripheral = device.peripheral else { return }
        
        connectionState = .connecting
        activePeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Disconnect from current device
    func disconnect() {
        guard let peripheral = activePeripheral else { return }
        
        connectionState = .disconnecting
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    /// Send APDU command to hardware wallet
    func sendAPDU(_ apdu: Data) async throws -> Data {
        guard connectionState == .connected,
              let writeChar = writeCharacteristic else {
            throw BluetoothError.notConnected
        }
        
        // Clear response buffer
        responseBuffer.removeAll()
        
        // Write APDU to device
        activePeripheral?.writeValue(apdu, for: writeChar, type: .withResponse)
        
        // Wait for response
        return try await withCheckedThrowingContinuation { continuation in
            self.responseContinuation = continuation
            
            // Timeout after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                if self?.responseContinuation != nil {
                    self?.responseContinuation?.resume(throwing: BluetoothError.timeout)
                    self?.responseContinuation = nil
                }
            }
        }
    }
    
    // MARK: - Device Type Detection
    
    private func detectDeviceType(name: String) -> HardwareDevice.DeviceType {
        let lowercasedName = name.lowercased()
        
        if lowercasedName.contains("nano x") {
            return .ledgerNanoX
        } else if lowercasedName.contains("nano s plus") || lowercasedName.contains("nano sp") {
            return .ledgerNanoSPlus
        }
        
        return .unknown
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.bluetoothState = central.state
            
            switch central.state {
            case .poweredOn:
                print("✅ Bluetooth is powered on")
            case .poweredOff:
                print("❌ Bluetooth is powered off")
            case .unauthorized:
                print("❌ Bluetooth access not authorized")
            case .unsupported:
                print("❌ Bluetooth not supported on this device")
            default:
                break
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, 
                      didDiscover peripheral: CBPeripheral,
                      advertisementData: [String : Any],
                      rssi RSSI: NSNumber) {
        Task { @MainActor in
            let name = peripheral.name ?? "Unknown Device"
            let deviceType = self.detectDeviceType(name: name)
            
            let device = HardwareDevice(
                id: peripheral.identifier,
                name: name,
                type: deviceType,
                rssi: RSSI.intValue,
                peripheral: peripheral
            )
            
            // Add if not already discovered
            if !self.discoveredDevices.contains(where: { $0.id == device.id }) {
                self.discoveredDevices.append(device)
                print("📱 Discovered: \(name)")
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("✅ Connected to \(peripheral.name ?? "device")")
            
            self.connectionState = .connected
            peripheral.delegate = self
            
            // Discover services
            peripheral.discoverServices([self.ledgerServiceUUID])
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, 
                      didDisconnectPeripheral peripheral: CBPeripheral,
                      error: Error?) {
        Task { @MainActor in
            print("📱 Disconnected from \(peripheral.name ?? "device")")
            
            self.connectionState = .disconnected
            self.connectedDevice = nil
            self.activePeripheral = nil
            self.writeCharacteristic = nil
            self.notifyCharacteristic = nil
            
            if let error = error {
                print("❌ Disconnect error: \(error.localizedDescription)")
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager,
                      didFailToConnect peripheral: CBPeripheral,
                      error: Error?) {
        Task { @MainActor in
            print("❌ Failed to connect: \(error?.localizedDescription ?? "unknown error")")
            self.connectionState = .disconnected
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ Service discovery error: \(error.localizedDescription)")
                return
            }
            
            guard let services = peripheral.services else { return }
            
            for service in services {
                print("🔍 Found service: \(service.uuid)")
                peripheral.discoverCharacteristics(
                    [self.ledgerWriteCharUUID, self.ledgerNotifyCharUUID],
                    for: service
                )
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral,
                  didDiscoverCharacteristicsFor service: CBService,
                  error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ Characteristic discovery error: \(error.localizedDescription)")
                return
            }
            
            guard let characteristics = service.characteristics else { return }
            
            for characteristic in characteristics {
                print("🔍 Found characteristic: \(characteristic.uuid)")
                
                if characteristic.uuid == self.ledgerWriteCharUUID {
                    self.writeCharacteristic = characteristic
                    print("✅ Write characteristic ready")
                }
                
                if characteristic.uuid == self.ledgerNotifyCharUUID {
                    self.notifyCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("✅ Notify characteristic ready")
                }
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral,
                  didUpdateValueFor characteristic: CBCharacteristic,
                  error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ Read error: \(error.localizedDescription)")
                self.responseContinuation?.resume(throwing: error)
                self.responseContinuation = nil
                return
            }
            
            guard let data = characteristic.value else { return }
            
            // Append to response buffer
            self.responseBuffer.append(data)
            
            // Check if response is complete (implementation depends on protocol)
            // For now, assume single packet response
            if let continuation = self.responseContinuation {
                continuation.resume(returning: self.responseBuffer)
                self.responseContinuation = nil
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral,
                  didWriteValueFor characteristic: CBCharacteristic,
                  error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ Write error: \(error.localizedDescription)")
            } else {
                print("✅ APDU sent successfully")
            }
        }
    }
}

// MARK: - Errors

enum BluetoothError: Error, LocalizedError {
    case notConnected
    case timeout
    case notSupported
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Hardware wallet not connected"
        case .timeout:
            return "Connection timeout"
        case .notSupported:
            return "Bluetooth not supported on this device"
        case .unauthorized:
            return "Bluetooth access not authorized"
        }
    }
}
