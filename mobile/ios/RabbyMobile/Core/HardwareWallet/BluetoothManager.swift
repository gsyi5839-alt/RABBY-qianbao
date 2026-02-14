import Foundation
import CoreBluetooth
import Combine

// MARK: - Ledger BLE Transport Framing
//
// Ledger devices use a custom framing protocol over BLE. Each APDU is wrapped in
// one or more BLE frames before being written to the write characteristic. The
// device responds with similarly-framed data on the notify characteristic.
//
// Frame layout (sent/received on the BLE characteristic):
//   Bytes 0-1 : Channel ID (0x0101 for BLE)
//   Byte  2   : Tag (0x05)
//   Bytes 3-4 : Sequence index (big-endian, 0x0000 for first frame)
//   --- first frame only ---
//   Bytes 5-6 : Total APDU payload length (big-endian)
//   Bytes 7.. : Payload fragment
//   --- subsequent frames ---
//   Bytes 5.. : Payload fragment
//
// The maximum BLE characteristic write size (MTU-dependent) determines how large
// each frame can be. We default to 20 bytes but negotiate upward when possible.

/// Bluetooth Manager for Hardware Wallet connections
/// Supports Ledger Nano X and Ledger Nano S Plus via Bluetooth Low Energy.
///
/// ## Integration with KeyringManager
///
/// `BluetoothManager` is used indirectly through `LedgerKeyring`. When
/// `KeyringManager.signTransaction` / `signMessage` / `signTypedData` iterates
/// over its keyrings and finds a `LedgerKeyring` that owns the target address,
/// the call is forwarded to the Ledger device via this BLE transport.
///
/// ```swift
/// // In KeyringManager.signTransaction:
/// // The existing loop already handles this automatically:
/// // for keyring in keyrings {
/// //     let accounts = await keyring.getAccounts()
/// //     if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
/// //         // If keyring is LedgerKeyring, this triggers BLE communication
/// //         return try await keyring.signTransaction(address: address, transaction: transaction)
/// //     }
/// // }
/// ```
@MainActor
class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()

    // MARK: - Published Properties

    @Published var isScanning = false
    @Published var discoveredDevices: [LedgerDevice] = []
    @Published var connectedDevice: LedgerDevice?
    @Published var connectionState: DeviceConnectionState = .disconnected
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var isSigning = false

    // MARK: - Device Connection State

    enum DeviceConnectionState: Equatable {
        case disconnected
        case scanning
        case connecting
        case discoveringServices
        case connected
        case disconnecting
    }

    // MARK: - Ledger Device Model

    struct LedgerDevice: Identifiable, Equatable {
        let id: UUID
        let name: String
        let type: DeviceType
        var rssi: Int
        var peripheral: CBPeripheral?
        var firmwareVersion: String?
        var batteryLevel: Int?

        enum DeviceType: String {
            case ledgerNanoX = "Ledger Nano X"
            case ledgerNanoSPlus = "Ledger Nano S Plus"
            case ledgerStax = "Ledger Stax"
            case unknown = "Hardware Wallet"
        }

        static func == (lhs: LedgerDevice, rhs: LedgerDevice) -> Bool {
            return lhs.id == rhs.id
        }
    }

    // Backward compatibility alias
    typealias HardwareDevice = LedgerDevice

    // MARK: - Private Properties

    private var centralManager: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    /// Negotiated MTU for the BLE connection. The Ledger framing protocol uses
    /// this to decide how many payload bytes fit per frame. Default BLE MTU is 23,
    /// minus 3 bytes ATT overhead = 20 usable bytes per write.
    private var mtu: Int = 20

    // Ledger BLE service and characteristic UUIDs
    private let ledgerServiceUUID = CBUUID(string: "13D63400-2C97-0004-0000-4C6564676572")
    private let ledgerWriteCharUUID = CBUUID(string: "13D63400-2C97-0004-0002-4C6564676572")
    private let ledgerNotifyCharUUID = CBUUID(string: "13D63400-2C97-0004-0001-4C6564676572")

    // Ledger BLE framing constants
    private let bleChannelID: UInt16 = 0x0101
    private let bleTag: UInt8 = 0x05

    // Response reassembly
    private var responseBuffer = Data()
    private var expectedResponseLength: Int = 0
    private var responseSequenceIndex: UInt16 = 0
    private var responseContinuation: CheckedContinuation<Data, Error>?

    // Scanning timer
    private var scanTimer: DispatchWorkItem?
    private let scanDuration: TimeInterval = 15

    // APDU response timeout
    private let apduTimeout: TimeInterval = 60

    // MARK: - Initialization

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public Methods: Scanning

    /// Start scanning for Ledger hardware wallets.
    /// Scans for devices advertising the Ledger BLE service UUID.
    /// Scanning auto-stops after `scanDuration` seconds.
    func startScanning() {
        guard bluetoothState == .poweredOn else {
            print("[BLE] Cannot scan: Bluetooth not powered on (state: \(bluetoothState.rawValue))")
            return
        }

        // Cancel any previous scan timer
        scanTimer?.cancel()
        scanTimer = nil

        discoveredDevices.removeAll()
        isScanning = true
        connectionState = .scanning

        centralManager.scanForPeripherals(
            withServices: [ledgerServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Auto-stop after scanDuration
        let timer = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if self.isScanning {
                    self.stopScanning()
                }
            }
        }
        scanTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + scanDuration, execute: timer)
    }

    /// Stop scanning for devices.
    func stopScanning() {
        scanTimer?.cancel()
        scanTimer = nil
        isScanning = false
        centralManager.stopScan()

        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    // MARK: - Public Methods: Connection

    /// Connect to a discovered Ledger device.
    func connect(to device: LedgerDevice) {
        guard let peripheral = device.peripheral else {
            print("[BLE] Cannot connect: no peripheral reference for device \(device.name)")
            return
        }

        stopScanning()

        connectionState = .connecting
        activePeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }

    /// Disconnect from the currently connected device.
    func disconnect() {
        guard let peripheral = activePeripheral else { return }

        connectionState = .disconnecting

        // Cancel any pending APDU response
        if let continuation = responseContinuation {
            continuation.resume(throwing: BluetoothError.disconnected)
            responseContinuation = nil
        }

        centralManager.cancelPeripheralConnection(peripheral)
    }

    // MARK: - Public Methods: APDU Transport

    /// Send a raw APDU command to the connected Ledger device and return the response.
    ///
    /// The APDU is wrapped in the Ledger BLE framing protocol, split across
    /// multiple BLE writes if necessary, and the response frames are reassembled
    /// into a single APDU response.
    ///
    /// - Parameter apdu: The raw APDU bytes (CLA INS P1 P2 [Lc] [Data]).
    /// - Returns: The APDU response data (without SW1/SW2, or with them depending on the command).
    /// - Throws: `BluetoothError` if not connected, timed out, or transport fails.
    func sendAPDU(_ apdu: Data) async throws -> Data {
        guard connectionState == .connected,
              let peripheral = activePeripheral,
              let writeChar = writeCharacteristic else {
            throw BluetoothError.notConnected
        }

        // Reset response state
        responseBuffer.removeAll()
        expectedResponseLength = 0
        responseSequenceIndex = 0

        // Frame the APDU using Ledger BLE transport protocol
        let frames = frameAPDU(apdu)

        // Send all frames
        for frame in frames {
            peripheral.writeValue(frame, for: writeChar, type: .withResponse)
        }

        // Wait for the complete response
        return try await withCheckedThrowingContinuation { continuation in
            self.responseContinuation = continuation

            // Timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + self.apduTimeout) { [weak self] in
                guard let self else { return }
                if let cont = self.responseContinuation {
                    cont.resume(throwing: BluetoothError.timeout)
                    self.responseContinuation = nil
                }
            }
        }
    }

    /// Send multiple APDU commands sequentially (for chunked operations like
    /// signTransaction). Returns the response from the **last** APDU.
    ///
    /// - Parameter apdus: An array of raw APDU data to send in order.
    /// - Returns: The response from the final APDU.
    func sendAPDUSequence(_ apdus: [Data]) async throws -> Data {
        guard !apdus.isEmpty else {
            throw BluetoothError.invalidAPDU
        }

        var lastResponse = Data()
        for apdu in apdus {
            lastResponse = try await sendAPDU(apdu)

            // Check for Ledger status word errors in intermediate responses.
            // The last 2 bytes of a Ledger response are SW1-SW2 when the response
            // is an error. For success the Ethereum app returns data without a
            // trailing status word, but error responses are exactly 2 bytes.
            if lastResponse.count == 2 {
                let sw = UInt16(lastResponse[0]) << 8 | UInt16(lastResponse[1])
                if sw != 0x9000 {
                    throw BluetoothError.apduError(statusWord: sw)
                }
            }
        }
        return lastResponse
    }

    // MARK: - Ledger BLE Framing

    /// Wrap a raw APDU into one or more BLE transport frames.
    ///
    /// First frame layout:
    ///   [channelID: 2 bytes] [tag: 1 byte] [seqIdx: 2 bytes = 0x0000] [payloadLen: 2 bytes] [payload fragment]
    ///
    /// Subsequent frames:
    ///   [channelID: 2 bytes] [tag: 1 byte] [seqIdx: 2 bytes] [payload fragment]
    private func frameAPDU(_ apdu: Data) -> [Data] {
        var frames: [Data] = []
        var offset = 0
        var sequenceIndex: UInt16 = 0

        // First frame: header(5 bytes) + length(2 bytes) + payload
        let firstFrameHeaderSize = 5 + 2  // channel(2) + tag(1) + seq(2) + length(2)
        let firstFramePayloadCapacity = max(mtu - firstFrameHeaderSize, 1)

        var firstFrame = Data()
        firstFrame.append(contentsOf: withUnsafeBytes(of: bleChannelID.bigEndian) { Array($0) })
        firstFrame.append(bleTag)
        firstFrame.append(contentsOf: withUnsafeBytes(of: sequenceIndex.bigEndian) { Array($0) })
        firstFrame.append(contentsOf: withUnsafeBytes(of: UInt16(apdu.count).bigEndian) { Array($0) })

        let firstChunkSize = min(firstFramePayloadCapacity, apdu.count)
        firstFrame.append(apdu[offset..<(offset + firstChunkSize)])
        offset += firstChunkSize

        // Pad to MTU if needed
        if firstFrame.count < mtu {
            firstFrame.append(Data(repeating: 0, count: mtu - firstFrame.count))
        }
        frames.append(firstFrame)

        sequenceIndex += 1

        // Subsequent frames: header(5 bytes) + payload
        let subsequentFrameHeaderSize = 5  // channel(2) + tag(1) + seq(2)
        let subsequentFramePayloadCapacity = max(mtu - subsequentFrameHeaderSize, 1)

        while offset < apdu.count {
            var frame = Data()
            frame.append(contentsOf: withUnsafeBytes(of: bleChannelID.bigEndian) { Array($0) })
            frame.append(bleTag)
            frame.append(contentsOf: withUnsafeBytes(of: sequenceIndex.bigEndian) { Array($0) })

            let chunkSize = min(subsequentFramePayloadCapacity, apdu.count - offset)
            frame.append(apdu[offset..<(offset + chunkSize)])
            offset += chunkSize

            // Pad to MTU
            if frame.count < mtu {
                frame.append(Data(repeating: 0, count: mtu - frame.count))
            }
            frames.append(frame)

            sequenceIndex += 1
        }

        return frames
    }

    /// Process a received BLE frame and reassemble the APDU response.
    /// When all frames for the current response have been received, resolves
    /// the pending continuation.
    private func processReceivedFrame(_ frame: Data) {
        guard frame.count >= 5 else {
            print("[BLE] Received frame too short (\(frame.count) bytes)")
            return
        }

        // Parse header
        let channelID = UInt16(frame[0]) << 8 | UInt16(frame[1])
        let tag = frame[2]
        let seqIndex = UInt16(frame[3]) << 8 | UInt16(frame[4])

        guard channelID == bleChannelID, tag == bleTag else {
            print("[BLE] Unexpected frame header: channel=\(channelID), tag=\(tag)")
            return
        }

        if seqIndex == 0 {
            // First frame of a new response
            guard frame.count >= 7 else {
                print("[BLE] First frame too short for length field")
                return
            }
            expectedResponseLength = Int(UInt16(frame[5]) << 8 | UInt16(frame[6]))
            responseBuffer.removeAll()
            responseSequenceIndex = 0

            let payloadStart = 7
            let payloadEnd = min(frame.count, payloadStart + expectedResponseLength)
            if payloadStart < frame.count {
                responseBuffer.append(frame[payloadStart..<payloadEnd])
            }
        } else {
            // Subsequent frame
            guard seqIndex == responseSequenceIndex + 1 else {
                print("[BLE] Unexpected sequence index: got \(seqIndex), expected \(responseSequenceIndex + 1)")
                return
            }
            responseSequenceIndex = seqIndex

            let payloadStart = 5
            let remaining = expectedResponseLength - responseBuffer.count
            let payloadEnd = min(frame.count, payloadStart + remaining)
            if payloadStart < frame.count && remaining > 0 {
                responseBuffer.append(frame[payloadStart..<payloadEnd])
            }
        }

        // Check if we have received the complete response
        if responseBuffer.count >= expectedResponseLength && expectedResponseLength > 0 {
            let completeResponse = Data(responseBuffer.prefix(expectedResponseLength))

            if let continuation = responseContinuation {
                continuation.resume(returning: completeResponse)
                responseContinuation = nil
            }
        }
    }

    // MARK: - Device Type Detection

    private func detectDeviceType(name: String) -> LedgerDevice.DeviceType {
        let lowercasedName = name.lowercased()

        if lowercasedName.contains("nano x") {
            return .ledgerNanoX
        } else if lowercasedName.contains("nano s plus") || lowercasedName.contains("nano sp") {
            return .ledgerNanoSPlus
        } else if lowercasedName.contains("stax") {
            return .ledgerStax
        }

        return .unknown
    }

    // MARK: - Connection State Helpers

    var isConnected: Bool {
        connectionState == .connected
    }

    var isReady: Bool {
        connectionState == .connected && writeCharacteristic != nil && notifyCharacteristic != nil
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.bluetoothState = central.state

            switch central.state {
            case .poweredOn:
                print("[BLE] Bluetooth powered on")
            case .poweredOff:
                print("[BLE] Bluetooth powered off")
                self.handleBluetoothOff()
            case .unauthorized:
                print("[BLE] Bluetooth unauthorized")
            case .unsupported:
                print("[BLE] Bluetooth unsupported")
            default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        Task { @MainActor in
            let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Ledger Device"
            let deviceType = self.detectDeviceType(name: name)

            let device = LedgerDevice(
                id: peripheral.identifier,
                name: name,
                type: deviceType,
                rssi: RSSI.intValue,
                peripheral: peripheral
            )

            // Update existing or add new
            if let existingIndex = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                self.discoveredDevices[existingIndex].rssi = RSSI.intValue
            } else {
                self.discoveredDevices.append(device)
                print("[BLE] Discovered device: \(name) (RSSI: \(RSSI.intValue))")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("[BLE] Connected to \(peripheral.name ?? "device")")

            self.connectionState = .discoveringServices
            peripheral.delegate = self

            // Negotiate MTU — iOS negotiates automatically but we read the result
            let negotiatedMTU = peripheral.maximumWriteValueLength(for: .withResponse)
            if negotiatedMTU > 0 {
                self.mtu = min(negotiatedMTU, 512)
            }
            print("[BLE] Negotiated MTU: \(self.mtu)")

            // Update connected device
            if let deviceIndex = self.discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
                self.connectedDevice = self.discoveredDevices[deviceIndex]
            } else {
                self.connectedDevice = LedgerDevice(
                    id: peripheral.identifier,
                    name: peripheral.name ?? "Ledger Device",
                    type: self.detectDeviceType(name: peripheral.name ?? ""),
                    rssi: 0,
                    peripheral: peripheral
                )
            }

            // Discover the Ledger BLE service
            peripheral.discoverServices([self.ledgerServiceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            print("[BLE] Disconnected from \(peripheral.name ?? "device")")

            self.connectionState = .disconnected
            self.connectedDevice = nil
            self.activePeripheral = nil
            self.writeCharacteristic = nil
            self.notifyCharacteristic = nil
            self.isSigning = false

            // Fail any pending APDU
            if let continuation = self.responseContinuation {
                continuation.resume(throwing: BluetoothError.disconnected)
                self.responseContinuation = nil
            }

            if let error = error {
                print("[BLE] Disconnect error: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            print("[BLE] Failed to connect: \(error?.localizedDescription ?? "unknown error")")
            self.connectionState = .disconnected
            self.activePeripheral = nil
        }
    }

    // MARK: - Private Helpers

    private func handleBluetoothOff() {
        stopScanning()
        if connectionState != .disconnected {
            connectionState = .disconnected
            connectedDevice = nil
            activePeripheral = nil
            writeCharacteristic = nil
            notifyCharacteristic = nil

            if let continuation = responseContinuation {
                continuation.resume(throwing: BluetoothError.bluetoothPoweredOff)
                responseContinuation = nil
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("[BLE] Service discovery error: \(error.localizedDescription)")
                self.connectionState = .disconnected
                return
            }

            guard let services = peripheral.services else {
                print("[BLE] No services found")
                self.connectionState = .disconnected
                return
            }

            for service in services where service.uuid == self.ledgerServiceUUID {
                print("[BLE] Found Ledger service: \(service.uuid)")
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
                print("[BLE] Characteristic discovery error: \(error.localizedDescription)")
                return
            }

            guard let characteristics = service.characteristics else { return }

            for characteristic in characteristics {
                if characteristic.uuid == self.ledgerWriteCharUUID {
                    self.writeCharacteristic = characteristic
                    print("[BLE] Write characteristic ready")
                }

                if characteristic.uuid == self.ledgerNotifyCharUUID {
                    self.notifyCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("[BLE] Notify characteristic ready")
                }
            }

            // Mark as fully connected once both characteristics are available
            if self.writeCharacteristic != nil && self.notifyCharacteristic != nil {
                self.connectionState = .connected
                print("[BLE] Device fully connected and ready for APDU exchange")
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didUpdateValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("[BLE] Notify error: \(error.localizedDescription)")
                if let continuation = self.responseContinuation {
                    continuation.resume(throwing: error)
                    self.responseContinuation = nil
                }
                return
            }

            guard let data = characteristic.value, !data.isEmpty else { return }

            // Process the received BLE frame through the Ledger framing protocol
            self.processReceivedFrame(data)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didWriteValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("[BLE] Write error: \(error.localizedDescription)")
                if let continuation = self.responseContinuation {
                    continuation.resume(throwing: BluetoothError.writeFailed(error.localizedDescription))
                    self.responseContinuation = nil
                }
            }
        }
    }
}

// MARK: - Errors

enum BluetoothError: Error, LocalizedError {
    case notConnected
    case disconnected
    case timeout
    case notSupported
    case unauthorized
    case bluetoothPoweredOff
    case invalidAPDU
    case writeFailed(String)
    case apduError(statusWord: UInt16)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Ledger device is not connected. Please connect via Bluetooth."
        case .disconnected:
            return "Ledger device disconnected unexpectedly."
        case .timeout:
            return "Communication with the Ledger device timed out. Please check the device screen."
        case .notSupported:
            return "Bluetooth is not supported on this device."
        case .unauthorized:
            return "Bluetooth access is not authorized. Please enable it in Settings."
        case .bluetoothPoweredOff:
            return "Bluetooth is turned off. Please enable Bluetooth to connect to your Ledger."
        case .invalidAPDU:
            return "Invalid APDU command."
        case .writeFailed(let detail):
            return "Failed to send data to the Ledger device: \(detail)"
        case .apduError(let sw):
            return Self.describeStatusWord(sw)
        }
    }

    /// Translate well-known Ledger Ethereum app status words into human-readable messages.
    static func describeStatusWord(_ sw: UInt16) -> String {
        switch sw {
        case 0x6700:
            return "Incorrect data length sent to the Ledger device."
        case 0x6982:
            return "Security condition not satisfied. Please unlock your Ledger and open the Ethereum app."
        case 0x6985:
            return "Transaction was rejected on the Ledger device."
        case 0x6A80:
            return "Invalid data received by the Ledger device."
        case 0x6B00:
            return "Invalid parameter sent to the Ledger device."
        case 0x6D00:
            return "The Ethereum app is not open on your Ledger. Please open it and try again."
        case 0x6E00:
            return "Wrong application selected on Ledger. Please open the Ethereum app."
        case 0x6FAA:
            return "Ledger device is locked. Please unlock it."
        case 0x9000:
            return "Success"
        default:
            return String(format: "Ledger device returned error code: 0x%04X", sw)
        }
    }
}
