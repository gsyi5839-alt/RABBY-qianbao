import Foundation
import CryptoKit
import BigInt

// MARK: - Keyring Types
enum KeyringType: String, Codable {
    case hdKeyring = "HD Key Tree"
    case simpleKeyring = "Simple Key Pair"
    case watchAddress = "Watch Address"
    case ledger = "Ledger Hardware"
    case trezor = "Trezor Hardware"
    case onekey = "Onekey Hardware"
    case bitbox02 = "BitBox02 Hardware"
    case gridplus = "GridPlus Hardware"
    case keystone = "Keystone Hardware"
    case imkey = "ImKey Hardware"
    case gnosis = "Gnosis"
    case walletConnect = "WalletConnect"
    case coinbase = "Coinbase Wallet"
    case coboArgus = "Cobo Argus"
}

// MARK: - Account Model
struct Account: Codable {
    let address: String
    let type: KeyringType
    let brandName: String
    var alianName: String?
    var balance: String?
    var index: Int?
    
    var checksumAddress: String {
        return EthereumUtil.toChecksumAddress(address)
    }
}

// MARK: - Keyring Protocol
protocol Keyring {
    var type: KeyringType { get }
    var accounts: [String] { get }
    
    func serialize() throws -> Data
    func deserialize(from data: Data) throws
    func addAccounts(count: Int) async throws -> [String]
    func getAccounts() async -> [String]
    func removeAccount(address: String) throws
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data
    func signMessage(address: String, message: Data) async throws -> Data
    func signTypedData(address: String, typedData: String) async throws -> Data
}

// MARK: - HD Keyring (BIP44)
class HDKeyring: Keyring {
    let type: KeyringType = .hdKeyring
    private(set) var accounts: [String] = []
    private var mnemonic: String?
    private var passphrase: String = ""
    private var numberOfAccounts: Int = 0
    private var hdPath: String = "m/44'/60'/0'/0"
    var index: Int = 0
    
    init() {}
    
    init(mnemonic: String, passphrase: String = "") {
        self.mnemonic = mnemonic
        self.passphrase = passphrase
    }
    
    // Generate mnemonic
    static func generateMnemonic(strength: Int = 128) throws -> String {
        guard strength % 32 == 0 && strength >= 128 && strength <= 256 else {
            throw KeyringError.invalidMnemonicStrength
        }
        
        let byteCount = strength / 8
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let result = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        
        guard result == errSecSuccess else {
            throw KeyringError.failedToGenerateMnemonic
        }
        
        return try BIP39.generateMnemonic(entropy: Data(bytes))
    }
    
    // Validate mnemonic
    static func validateMnemonic(_ mnemonic: String) -> Bool {
        return BIP39.validateMnemonic(mnemonic)
    }
    
    // Add accounts from mnemonic
    func addAccounts(count: Int = 1) async throws -> [String] {
        guard let mnemonic = mnemonic else {
            throw KeyringError.mnemonicNotSet
        }
        
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase)
        var newAccounts: [String] = []
        
        for i in numberOfAccounts..<(numberOfAccounts + count) {
            let path = "\(hdPath)/\(i)"
            let privateKey = try derivePrivateKey(seed: seed, path: path)
            let address = try EthereumUtil.privateKeyToAddress(privateKey)
            newAccounts.append(address)
            accounts.append(address)
        }
        
        numberOfAccounts += count
        return newAccounts
    }
    
    func getAccounts() async -> [String] {
        return accounts
    }
    
    func removeAccount(address: String) throws {
        guard let index = accounts.firstIndex(where: { $0.lowercased() == address.lowercased() }) else {
            throw KeyringError.accountNotFound
        }
        accounts.remove(at: index)
        numberOfAccounts -= 1
    }
    
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data {
        guard accounts.contains(where: { $0.lowercased() == address.lowercased() }) else {
            throw KeyringError.accountNotFound
        }
        
        guard let mnemonic = mnemonic else {
            throw KeyringError.mnemonicNotSet
        }
        
        let index = accounts.firstIndex { $0.lowercased() == address.lowercased() }!
        let path = "\(hdPath)/\(index)"
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase)
        let privateKey = try derivePrivateKey(seed: seed, path: path)
        
        return try EthereumSigner.signTransaction(privateKey: privateKey, transaction: transaction)
    }
    
    func signMessage(address: String, message: Data) async throws -> Data {
        guard accounts.contains(where: { $0.lowercased() == address.lowercased() }) else {
            throw KeyringError.accountNotFound
        }
        
        guard let mnemonic = mnemonic else {
            throw KeyringError.mnemonicNotSet
        }
        
        let index = accounts.firstIndex { $0.lowercased() == address.lowercased() }!
        let path = "\(hdPath)/\(index)"
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase)
        let privateKey = try derivePrivateKey(seed: seed, path: path)
        
        return try EthereumSigner.signMessage(privateKey: privateKey, message: message)
    }
    
    func signTypedData(address: String, typedData: String) async throws -> Data {
        guard accounts.contains(where: { $0.lowercased() == address.lowercased() }) else {
            throw KeyringError.accountNotFound
        }
        
        guard let mnemonic = mnemonic else {
            throw KeyringError.mnemonicNotSet
        }
        
        let index = accounts.firstIndex { $0.lowercased() == address.lowercased() }!
        let path = "\(hdPath)/\(index)"
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase)
        let privateKey = try derivePrivateKey(seed: seed, path: path)
        
        return try EthereumSigner.signTypedData(privateKey: privateKey, typedDataJSON: typedData)
    }
    
    func serialize() throws -> Data {
        let dict: [String: Any] = [
            "mnemonic": mnemonic ?? "",
            "passphrase": passphrase,
            "numberOfAccounts": numberOfAccounts,
            "hdPath": hdPath,
            "accounts": accounts,
            "index": index
        ]
        return try JSONSerialization.data(withJSONObject: dict)
    }
    
    func deserialize(from data: Data) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KeyringError.invalidSerializedData
        }
        
        self.mnemonic = dict["mnemonic"] as? String
        self.passphrase = dict["passphrase"] as? String ?? ""
        self.numberOfAccounts = dict["numberOfAccounts"] as? Int ?? 0
        self.hdPath = dict["hdPath"] as? String ?? "m/44'/60'/0'/0"
        self.accounts = dict["accounts"] as? [String] ?? []
        self.index = dict["index"] as? Int ?? 0
    }
    
    // BIP44 derivation
    private func derivePrivateKey(seed: Data, path: String) throws -> Data {
        // Implement BIP44 key derivation
        // This requires a crypto library like Web3.swift or similar
        return try BIP44.derivePrivateKey(seed: seed, path: path)
    }
}

// MARK: - Simple Keyring (Private Key)
class SimpleKeyring: Keyring {
    let type: KeyringType = .simpleKeyring
    private(set) var accounts: [String] = []
    private var privateKeys: [String: Data] = [:]
    
    init() {}
    
    init(privateKeys: [Data]) throws {
        for privateKey in privateKeys {
            let address = try EthereumUtil.privateKeyToAddress(privateKey)
            self.accounts.append(address)
            self.privateKeys[address.lowercased()] = privateKey
        }
    }
    
    func addAccounts(count: Int = 1) async throws -> [String] {
        // Simple keyring doesn't support generating new random accounts
        throw KeyringError.operationNotSupported
    }
    
    /// Add accounts from existing private keys
    func addAccounts(privateKeys: [Data]) throws -> [String] {
        var newAccounts: [String] = []
        for privateKey in privateKeys {
            let address = try EthereumUtil.privateKeyToAddress(privateKey)
            if !accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                accounts.append(address)
                self.privateKeys[address.lowercased()] = privateKey
                newAccounts.append(address)
            }
        }
        return newAccounts
    }
    
    func getAccounts() async -> [String] {
        return accounts
    }
    
    func removeAccount(address: String) throws {
        guard let index = accounts.firstIndex(where: { $0.lowercased() == address.lowercased() }) else {
            throw KeyringError.accountNotFound
        }
        accounts.remove(at: index)
        privateKeys.removeValue(forKey: address.lowercased())
    }
    
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data {
        guard let privateKey = privateKeys[address.lowercased()] else {
            throw KeyringError.accountNotFound
        }
        return try EthereumSigner.signTransaction(privateKey: privateKey, transaction: transaction)
    }
    
    func signMessage(address: String, message: Data) async throws -> Data {
        guard let privateKey = privateKeys[address.lowercased()] else {
            throw KeyringError.accountNotFound
        }
        return try EthereumSigner.signMessage(privateKey: privateKey, message: message)
    }
    
    func signTypedData(address: String, typedData: String) async throws -> Data {
        guard let privateKey = privateKeys[address.lowercased()] else {
            throw KeyringError.accountNotFound
        }
        return try EthereumSigner.signTypedData(privateKey: privateKey, typedDataJSON: typedData)
    }
    
    func serialize() throws -> Data {
        let dict: [String: Any] = [
            "accounts": accounts,
            "privateKeys": privateKeys.mapValues { $0.hexString }
        ]
        return try JSONSerialization.data(withJSONObject: dict)
    }
    
    func deserialize(from data: Data) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KeyringError.invalidSerializedData
        }
        
        self.accounts = dict["accounts"] as? [String] ?? []
        if let keysDict = dict["privateKeys"] as? [String: String] {
            self.privateKeys = keysDict.compactMapValues { Data(hexString: $0) }
        }
    }
}

// MARK: - Watch Address Keyring is defined in WatchGnosisSessionKeyrings.swift

// MARK: - Keyring Manager
@MainActor
class KeyringManager: ObservableObject {
    static let shared = KeyringManager()
    
    @Published var isUnlocked: Bool = false
    @Published var isInitialized: Bool = false
    @Published var biometricsEnabled: Bool = false
    @Published var keyrings: [Keyring] = []
    @Published var currentAccount: Account?
    
    private var password: String?
    private let storageManager = StorageManager.shared
    
    private init() {
        // Check if vault exists
        Task {
            let vault = try? await storageManager.getEncryptedVault()
            await MainActor.run { self.isInitialized = vault != nil }
        }
    }
    
    // MARK: - Vault Creation
    func createNewVault(password: String) async {
        self.password = password
        self.isInitialized = true
        self.isUnlocked = true
    }
    
    // MARK: - Unlock/Lock
    func submitPassword(_ password: String) async throws {
        let valid = try await verifyPassword(password)
        guard valid else { throw KeyringError.invalidPassword }
        self.password = password
        self.keyrings = try await unlockKeyrings(password: password)
        self.isUnlocked = true
        NotificationCenter.default.post(name: .keyringUnlocked, object: nil)
    }
    
    func setLocked() async {
        keyrings.removeAll()
        password = nil
        isUnlocked = false
        NotificationCenter.default.post(name: .keyringLocked, object: nil)
    }
    
    @discardableResult
    func verifyPassword(_ password: String) async throws -> Bool {
        let encryptedVault = try? await storageManager.getEncryptedVault()
        guard let vault = encryptedVault else {
            // No vault yet — password is accepted for new vault
            return true
        }
        do {
            _ = try await storageManager.decrypt(data: vault, password: password)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Keyring Operations
    func addNewKeyring(type: KeyringType, options: [String: Any]? = nil) async throws -> Keyring {
        let keyring: Keyring
        
        switch type {
        case .hdKeyring:
            if let mnemonic = options?["mnemonic"] as? String {
                keyring = HDKeyring(mnemonic: mnemonic, passphrase: options?["passphrase"] as? String ?? "")
            } else {
                let mnemonic = try HDKeyring.generateMnemonic()
                keyring = HDKeyring(mnemonic: mnemonic)
            }
            
        case .simpleKeyring:
            if let privateKeyHex = options?["privateKey"] as? String,
               let privateKey = Data(hexString: privateKeyHex) {
                keyring = try SimpleKeyring(privateKeys: [privateKey])
            } else {
                throw KeyringError.invalidOptions
            }
            
        case .watchAddress:
            keyring = WatchAddressKeyring()
            if let addresses = options?["addresses"] as? [String] {
                for _ in addresses {
                    _ = try await keyring.addAccounts(count: 1)
                }
            }
            
        default:
            throw KeyringError.unsupportedKeyringType
        }
        
        keyrings.append(keyring)
        try await persistAllKeyrings()
        
        return keyring
    }
    
    func getAccounts() async -> [String] {
        var allAccounts: [String] = []
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            allAccounts.append(contentsOf: accounts)
        }
        return allAccounts
    }
    
    func removeAccount(address: String, type: KeyringType) async throws {
        guard let keyring = keyrings.first(where: { $0.type == type }) else {
            throw KeyringError.keyringNotFound
        }
        
        try keyring.removeAccount(address: address)
        try await persistAllKeyrings()
        
        NotificationCenter.default.post(
            name: .accountRemoved,
            object: nil,
            userInfo: ["address": address, "type": type.rawValue]
        )
    }
    
    func signTransaction(address: String, transaction: EthereumTransaction) async throws -> Data {
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                return try await keyring.signTransaction(address: address, transaction: transaction)
            }
        }
        throw KeyringError.accountNotFound
    }
    
    func signMessage(address: String, message: Data) async throws -> Data {
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                return try await keyring.signMessage(address: address, message: message)
            }
        }
        throw KeyringError.accountNotFound
    }
    
    func signTypedData(address: String, typedData: String) async throws -> Data {
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                return try await keyring.signTypedData(address: address, typedData: typedData)
            }
        }
        throw KeyringError.accountNotFound
    }
    
    // MARK: - Keyring Lifecycle
    func addKeyring(_ keyring: Keyring) async {
        keyrings.append(keyring)
        let accounts = await keyring.getAccounts()
        if currentAccount == nil, let firstAddr = accounts.first {
            currentAccount = Account(address: firstAddr, type: keyring.type, brandName: keyring.type.rawValue)
        }
    }
    
    // MARK: - Import Methods
    func importPrivateKey(privateKey: String, password: String?) async throws {
        if let pw = password, !isInitialized {
            await createNewVault(password: pw)
        }
        var cleanKey = privateKey
        if cleanKey.hasPrefix("0x") { cleanKey = String(cleanKey.dropFirst(2)) }
        guard let keyData = Data(hexString: cleanKey) else {
            throw KeyringError.invalidOptions
        }
        let keyring = try SimpleKeyring(privateKeys: [keyData])
        await addKeyring(keyring)
        try await persistAllKeyrings()
    }
    
    func importFromMnemonic(mnemonic: String, password: String?, accountCount: Int) async throws {
        if let pw = password, !isInitialized {
            await createNewVault(password: pw)
        }
        let keyring = HDKeyring(mnemonic: mnemonic)
        _ = try await keyring.addAccounts(count: accountCount)
        await addKeyring(keyring)
        try await persistAllKeyrings()
    }
    
    func importFromKeystore(json: String, password: String, walletPassword: String?) async throws {
        if let wp = walletPassword, !isInitialized {
            await createNewVault(password: wp)
        }
        // Decrypt keystore JSON to extract private key
        guard let jsonData = json.data(using: .utf8),
              let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw KeyringError.invalidSerializedData
        }
        // In production: use proper keystore decryption (scrypt/pbkdf2 + AES-128-CTR)
        // For now, validate the JSON structure
        guard jsonObj["crypto"] != nil || jsonObj["Crypto"] != nil else {
            throw KeyringError.invalidSerializedData
        }
        // Placeholder: actual decryption would extract private key here
        throw KeyringError.operationNotSupported
    }
    
    func restoreFromMnemonic(mnemonic: String, password: String) async throws {
        guard HDKeyring.validateMnemonic(mnemonic) else {
            throw KeyringError.mnemonicNotSet
        }
        // Reset vault with new password
        await createNewVault(password: password)
        keyrings.removeAll()
        try await importFromMnemonic(mnemonic: mnemonic, password: nil, accountCount: 1)
    }
    
    // MARK: - HD Derivation Helpers
    func deriveAddresses(mnemonic: String, hdPath: String, startIndex: Int, count: Int) async throws -> [String] {
        // Use the stored mnemonic if empty string passed
        var mnemonicToUse = mnemonic
        if mnemonicToUse.isEmpty {
            mnemonicToUse = try getStoredMnemonic()
        }
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonicToUse, passphrase: "")
        var addresses: [String] = []
        for i in startIndex..<(startIndex + count) {
            let path = "\(hdPath)/\(i)"
            let privateKey = try BIP44.derivePrivateKey(seed: seed, path: path)
            let address = try EthereumUtil.privateKeyToAddress(privateKey)
            addresses.append(address)
        }
        return addresses
    }
    
    func getAllAddresses() async -> [String] {
        return await getAccounts()
    }
    
    func addAccountFromExistingMnemonic(address: String) async throws {
        // Find the HD keyring and add the next account
        guard let hdKeyring = keyrings.first(where: { $0.type == .hdKeyring }) as? HDKeyring else {
            throw KeyringError.keyringNotFound
        }
        _ = try await hdKeyring.addAccounts(count: 1)
        try await persistAllKeyrings()
    }
    
    // MARK: - Export Methods
    func getMnemonic(password: String) async throws -> String {
        let valid = try await verifyPassword(password)
        guard valid else { throw KeyringError.invalidPassword }
        return try getStoredMnemonic()
    }
    
    func exportPrivateKey(address: String, password: String) async throws -> String {
        let valid = try await verifyPassword(password)
        guard valid else { throw KeyringError.invalidPassword }
        // Find keyring containing this address and export
        for keyring in keyrings {
            let accounts = await keyring.getAccounts()
            if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
                let data = try keyring.serialize()
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let keys = dict["privateKeys"] as? [String: String],
                   let key = keys[address.lowercased()] {
                    return "0x" + key
                }
                // For HD keyrings, derive the key
                if keyring.type == .hdKeyring {
                    return "0x" + (try keyring.serialize().hexString)
                }
                throw KeyringError.operationNotSupported
            }
        }
        throw KeyringError.accountNotFound
    }
    
    private func getStoredMnemonic() throws -> String {
        guard let hdKeyring = keyrings.first(where: { $0.type == .hdKeyring }) as? HDKeyring else {
            throw KeyringError.keyringNotFound
        }
        let data = try hdKeyring.serialize()
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mnemonic = dict["mnemonic"] as? String, !mnemonic.isEmpty else {
            throw KeyringError.mnemonicNotSet
        }
        return mnemonic
    }
    
    // MARK: - Sign and Send
    func signAndSendTransaction(from: String, to: String?, value: String?, data: String?, gasLimit: String?, gasPrice: String?) async throws -> String {
        let chain = ChainManager.shared.selectedChain ?? Chain.ethereum
        
        // Convert string values to proper types
        let valueHex = value ?? "0x0"
        let valueBigUInt = BigUInt(valueHex.replacingOccurrences(of: "0x", with: ""), radix: 16) ?? BigUInt(0)
        
        let dataHex = data ?? "0x"
        let dataBytes = dataHex.hexToData() ?? Data()
        
        let gasLimitValue = BigUInt(gasLimit ?? "21000") ?? BigUInt(21000)
        
        // Get nonce
        let nonceHex = try await NetworkManager.shared.getTransactionCount(address: from, chain: chain)
        let nonce = BigUInt(nonceHex.replacingOccurrences(of: "0x", with: ""), radix: 16) ?? BigUInt(0)
        
        let tx = EthereumTransaction(
            to: to,
            from: from,
            nonce: nonce,
            value: valueBigUInt,
            data: dataBytes,
            gasLimit: gasLimitValue,
            chainId: chain.id
        )
        
        let signedTx = try await signTransaction(address: from, transaction: tx)
        let hash = try await TransactionManager.shared.broadcastTransaction(signedTx)
        return hash
    }
    
    // MARK: - Persistence
    func persistAllKeyrings() async throws {
        guard let password = password else {
            throw KeyringError.walletLocked
        }
        
        var serializedKeyrings: [[String: Any]] = []
        for keyring in keyrings {
            let data = try keyring.serialize()
            serializedKeyrings.append([
                "type": keyring.type.rawValue,
                "data": data.base64EncodedString()
            ])
        }
        
        let vaultData = try JSONSerialization.data(withJSONObject: serializedKeyrings)
        try await storageManager.saveEncryptedVault(data: vaultData, password: password)
    }
    
    private func unlockKeyrings(password: String) async throws -> [Keyring] {
        guard let encryptedVault = try await storageManager.getEncryptedVault() else {
            return []
        }
        
        let vaultData = try await storageManager.decrypt(data: encryptedVault, password: password)
        guard let serializedKeyrings = try JSONSerialization.jsonObject(with: vaultData) as? [[String: Any]] else {
            return []
        }
        
        var loadedKeyrings: [Keyring] = []
        
        for item in serializedKeyrings {
            guard let typeString = item["type"] as? String,
                  let type = KeyringType(rawValue: typeString),
                  let dataString = item["data"] as? String,
                  let data = Data(base64Encoded: dataString) else {
                continue
            }
            
            let keyring: Keyring
            switch type {
            case .hdKeyring:
                keyring = HDKeyring()
            case .simpleKeyring:
                keyring = SimpleKeyring()
            case .watchAddress:
                keyring = WatchAddressKeyring()
            default:
                continue
            }
            
            try keyring.deserialize(from: data)
            loadedKeyrings.append(keyring)
        }
        
        return loadedKeyrings
    }
}

// MARK: - Errors
enum KeyringError: Error, LocalizedError {
    case invalidMnemonicStrength
    case failedToGenerateMnemonic
    case mnemonicNotSet
    case accountNotFound
    case operationNotSupported
    case watchAddressCannotSign
    case invalidSerializedData
    case vaultNotInitialized
    case walletLocked
    case keyringNotFound
    case unsupportedKeyringType
    case invalidOptions
    case invalidPassword
    
    var errorDescription: String? {
        switch self {
        case .invalidMnemonicStrength:
            return "Invalid mnemonic strength. Must be 128, 160, 192, 224, or 256."
        case .failedToGenerateMnemonic:
            return "Failed to generate secure random bytes for mnemonic."
        case .mnemonicNotSet:
            return "Mnemonic phrase is not set for this keyring."
        case .accountNotFound:
            return "Account not found in any keyring."
        case .operationNotSupported:
            return "This operation is not supported for this keyring type."
        case .watchAddressCannotSign:
            return "Watch addresses cannot sign transactions or messages."
        case .invalidSerializedData:
            return "Invalid serialized keyring data."
        case .vaultNotInitialized:
            return "Wallet vault is not initialized. Create a new wallet first."
        case .walletLocked:
            return "Wallet is locked. Please unlock first."
        case .keyringNotFound:
            return "Keyring not found."
        case .unsupportedKeyringType:
            return "Unsupported keyring type."
        case .invalidOptions:
            return "Invalid options provided."
        case .invalidPassword:
            return "Invalid password."
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let keyringUnlocked = Notification.Name("keyringUnlocked")
    static let keyringLocked = Notification.Name("keyringLocked")
    static let accountRemoved = Notification.Name("accountRemoved")
}
