import Foundation
import Combine

// MARK: - Type Aliases for Ledger

typealias KeyringProtocol = Keyring
typealias KeyringAccount = String
typealias SignedTransaction = Data

/// Ledger Hardware Wallet Keyring
/// Supports Ledger Nano X via Bluetooth
class LedgerKeyring: KeyringProtocol {
    let type: KeyringType = .ledger
    var accounts: [KeyringAccount] = []
    
    private var bluetoothManager: BluetoothManager {
        BluetoothManager.shared
    }
    private var cancellables = Set<AnyCancellable>()
    
    // Ledger APDU commands for Ethereum app
    private struct LedgerAPDU {
        // Get Ethereum address command
        static func getAddress(path: String, display: Bool = false) -> Data {
            var data = Data([0xE0, 0x02, display ? 0x01 : 0x00, 0x00])
            
            // Parse BIP44 path
            let pathComponents = path.components(separatedBy: "/")
                .filter { !$0.isEmpty && $0 != "m" }
            
            var pathData = Data()
            pathData.append(UInt8(pathComponents.count))
            
            for component in pathComponents {
                var value: UInt32 = 0
                var hardened = false
                
                if component.hasSuffix("'") {
                    hardened = true
                    value = UInt32(component.dropLast()) ?? 0
                } else {
                    value = UInt32(component) ?? 0
                }
                
                if hardened {
                    value |= 0x80000000
                }
                
                pathData.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Array($0) })
            }
            
            data.append(UInt8(pathData.count))
            data.append(pathData)
            
            return data
        }
        
        // Sign transaction command
        static func signTransaction(path: String, rawTx: Data) -> Data {
            var data = Data([0xE0, 0x04, 0x00, 0x00])
            
            // Parse BIP44 path
            let pathComponents = path.components(separatedBy: "/")
                .filter { !$0.isEmpty && $0 != "m" }
            
            var pathData = Data()
            pathData.append(UInt8(pathComponents.count))
            
            for component in pathComponents {
                var value: UInt32 = 0
                var hardened = false
                
                if component.hasSuffix("'") {
                    hardened = true
                    value = UInt32(component.dropLast()) ?? 0
                } else {
                    value = UInt32(component) ?? 0
                }
                
                if hardened {
                    value |= 0x80000000
                }
                
                pathData.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Array($0) })
            }
            
            data.append(UInt8(pathData.count + rawTx.count))
            data.append(pathData)
            data.append(rawTx)
            
            return data
        }
        
        // Sign message command (personal_sign)
        static func signMessage(path: String, message: Data) -> Data {
            var data = Data([0xE0, 0x08, 0x00, 0x00])
            
            // Parse BIP44 path
            let pathComponents = path.components(separatedBy: "/")
                .filter { !$0.isEmpty && $0 != "m" }
            
            var pathData = Data()
            pathData.append(UInt8(pathComponents.count))
            
            for component in pathComponents {
                var value: UInt32 = 0
                var hardened = false
                
                if component.hasSuffix("'") {
                    hardened = true
                    value = UInt32(component.dropLast()) ?? 0
                } else {
                    value = UInt32(component) ?? 0
                }
                
                if hardened {
                    value |= 0x80000000
                }
                
                pathData.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Array($0) })
            }
            
            // Message length (4 bytes big endian)
            let messageLength = UInt32(message.count).bigEndian
            var messageLengthData = Data()
            messageLengthData.append(contentsOf: withUnsafeBytes(of: messageLength) { Array($0) })
            
            data.append(UInt8(pathData.count + messageLengthData.count + message.count))
            data.append(pathData)
            data.append(messageLengthData)
            data.append(message)
            
            return data
        }
    }
    
    // MARK: - KeyringProtocol Implementation
    
    func serialize() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(accounts)
    }
    
    func deserialize(from data: Data) throws {
        let decoder = JSONDecoder()
        accounts = try decoder.decode([String].self, from: data)
    }
    
    func addAccounts(count: Int) async throws -> [String] {
        // For Ledger, we don't "add" accounts, we discover them
        // User must unlock device and open Ethereum app first
        let connectionState = await MainActor.run { bluetoothManager.connectionState }
        guard connectionState == .connected else {
            throw LedgerError.notConnected
        }
        
        var newAccounts: [String] = []
        let startIndex = accounts.count
        
        for i in 0..<count {
            let index = startIndex + i
            let path = "m/44'/60'/0'/0/\(index)"
            
            // Get address from Ledger
            let apdu = LedgerAPDU.getAddress(path: path, display: false)
            let response = try await bluetoothManager.sendAPDU(apdu)
            
            // Parse response
            let address = try parseLedgerAddressResponse(response)
            newAccounts.append(address)
        }
        
        accounts.append(contentsOf: newAccounts)
        return newAccounts
    }
    
    func getAccounts() async -> [String] {
        return accounts
    }
    
    func removeAccount(address: String) throws {
        accounts.removeAll { $0.lowercased() == address.lowercased() }
    }
    
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data {
        let connectionState = await MainActor.run { bluetoothManager.connectionState }
        guard connectionState == .connected else {
            throw LedgerError.notConnected
        }
        
        guard accounts.contains(where: { $0.lowercased() == address.lowercased() }) else {
            throw LedgerError.accountNotFound
        }
        
        // Find the account index
        guard let accountIndex = accounts.firstIndex(where: { $0.lowercased() == address.lowercased() }) else {
            throw LedgerError.accountNotFound
        }
        
        let path = "m/44'/60'/0'/0/\(accountIndex)"
        
        // Encode transaction to RLP
        let rawTx = try transaction.rlpEncode()
        
        // Sign with Ledger
        let apdu = LedgerAPDU.signTransaction(path: path, rawTx: rawTx)
        let response = try await bluetoothManager.sendAPDU(apdu)
        
        // Parse signature and return as Data
        let signature = try parseLedgerSignatureData(response)
        return signature
    }
    
    func signMessage(address: String, message: Data) async throws -> Data {
        let connectionState = await MainActor.run { bluetoothManager.connectionState }
        guard connectionState == .connected else {
            throw LedgerError.notConnected
        }
        
        guard accounts.contains(where: { $0.lowercased() == address.lowercased() }) else {
            throw LedgerError.accountNotFound
        }
        
        guard let accountIndex = accounts.firstIndex(where: { $0.lowercased() == address.lowercased() }) else {
            throw LedgerError.accountNotFound
        }
        
        let path = "m/44'/60'/0'/0/\(accountIndex)"
        
        // Sign message with Ledger
        let apdu = LedgerAPDU.signMessage(path: path, message: message)
        let response = try await bluetoothManager.sendAPDU(apdu)
        
        // Parse signature
        let signature = try parseLedgerSignatureData(response)
        return signature
    }
    
    func signTypedData(address: String, typedData: String) async throws -> Data {
        // Ledger EIP-712 signing requires special APDU commands
        // For now, fallback to message signing
        guard let jsonData = typedData.data(using: .utf8) else {
            throw LedgerError.unsupportedFormat
        }
        return try await signMessage(address: address, message: jsonData)
    }
    
    // MARK: - Helper Methods
    
    private func parseLedgerAddressResponse(_ response: Data) throws -> String {
        // Ledger address response format:
        // [public key length (1 byte)][public key][address length (1 byte)][address][chain code]
        
        guard response.count > 2 else {
            throw LedgerError.invalidResponse
        }
        
        let publicKeyLength = Int(response[0])
        guard response.count > 1 + publicKeyLength + 1 else {
            throw LedgerError.invalidResponse
        }
        
        let addressLengthIndex = 1 + publicKeyLength
        let addressLength = Int(response[addressLengthIndex])
        
        guard response.count >= addressLengthIndex + 1 + addressLength else {
            throw LedgerError.invalidResponse
        }
        
        let addressStart = addressLengthIndex + 1
        let addressEnd = addressStart + addressLength
        let addressData = response[addressStart..<addressEnd]
        
        // Convert to hex string with 0x prefix
        let address = "0x" + addressData.map { String(format: "%02x", $0) }.joined()
        
        return address
    }
    
    private func parseLedgerSignatureResponse(_ response: Data) throws -> (r: Data, s: Data, v: UInt8) {
        // Ledger signature response format:
        // [v (1 byte)][r (32 bytes)][s (32 bytes)]
        
        guard response.count >= 65 else {
            throw LedgerError.invalidResponse
        }
        
        let v = response[0]
        let r = response[1..<33]
        let s = response[33..<65]
        
        return (Data(r), Data(s), v)
    }
    
    private func parseLedgerSignatureData(_ response: Data) throws -> Data {
        let (r, s, v) = try parseLedgerSignatureResponse(response)
        
        // Combine signature components into single Data
        var signature = Data()
        signature.append(r)
        signature.append(s)
        signature.append(v)
        
        return signature
    }
    
    /// Check if Ethereum app is open on Ledger
    func checkEthereumApp() async throws -> (appName: String, version: String) {
        let apdu = Data([0xB0, 0x01, 0x00, 0x00, 0x00])
        let response = try await bluetoothManager.sendAPDU(apdu)
        
        guard response.count > 2 else {
            throw LedgerError.invalidResponse
        }
        
        var index = 0
        let format = response[index]
        index += 1
        
        guard format == 1 else {
            throw LedgerError.unsupportedFormat
        }
        
        let nameLength = Int(response[index])
        index += 1
        
        let appNameData = response[index..<(index + nameLength)]
        let appName = String(data: appNameData, encoding: .ascii) ?? "Unknown"
        index += nameLength
        
        let versionLength = Int(response[index])
        index += 1
        
        let versionData = response[index..<(index + versionLength)]
        let version = String(data: versionData, encoding: .ascii) ?? "Unknown"
        
        return (appName, version)
    }
}

// MARK: - Errors

enum LedgerError: Error, LocalizedError {
    case notConnected
    case accountNotFound
    case invalidResponse
    case invalidData
    case cannotExport
    case unsupportedFormat
    case ethereumAppNotOpen
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Ledger device not connected. Please connect via Bluetooth."
        case .accountNotFound:
            return "Account not found on this Ledger device"
        case .invalidResponse:
            return "Invalid response from Ledger device"
        case .invalidData:
            return "Invalid data received from Ledger device"
        case .cannotExport:
            return "Cannot export private keys from hardware wallet"
        case .unsupportedFormat:
            return "Unsupported response format"
        case .ethereumAppNotOpen:
            return "Please open the Ethereum app on your Ledger device"
        }
    }
}
