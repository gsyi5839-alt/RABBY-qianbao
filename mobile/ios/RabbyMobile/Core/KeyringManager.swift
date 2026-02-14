import Foundation
import BigInt
import CryptoSwift

// MARK: - Ledger Keyring Integration
//
// LedgerKeyring is fully integrated into KeyringManager through the Keyring protocol.
// The existing signTransaction / signMessage / signTypedData methods iterate over all
// keyrings and automatically route to LedgerKeyring when the target address belongs
// to a Ledger account:
//
//   // In KeyringManager.signTransaction (already implemented):
//   for keyring in keyrings {
//       let accounts = await keyring.getAccounts()
//       if accounts.contains(where: { $0.lowercased() == address.lowercased() }) {
//           // If keyring is LedgerKeyring, this sends APDU commands via BLE
//           return try await keyring.signTransaction(address: address, transaction: transaction)
//       }
//   }
//
// LedgerKeyring accounts are persisted in the vault. When the vault is unlocked,
// LedgerKeyring is restored (see unlockKeyrings). The Ledger device must be
// reconnected via BLE before signing, but account addresses are remembered.

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
        print("[HDKeyring] 🔵 Initializing with mnemonic: \(mnemonic.split(separator: " ").count) words, passphrase: \(passphrase.isEmpty ? "empty" : "set")")
        self.mnemonic = mnemonic
        self.passphrase = passphrase
        print("[HDKeyring] 🔵 Mnemonic stored: \(self.mnemonic != nil ? "YES" : "NO")")
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
        print("[HDKeyring] 🟡 addAccounts called, count: \(count)")
        print("[HDKeyring] 🟡 Current mnemonic status: \(mnemonic != nil ? "SET" : "NIL")")
        if let m = mnemonic {
            print("[HDKeyring] 🟡 Mnemonic length: \(m.isEmpty ? "EMPTY STRING" : "\(m.split(separator: " ").count) words")")
        }

        guard let mnemonic = mnemonic, !mnemonic.isEmpty else {
            print("[HDKeyring] ❌ ERROR: addAccounts called but mnemonic is not set or empty")
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
        print("[HDKeyring] 🟢 serialize() called")
        print("[HDKeyring] 🟢 Mnemonic status before check: \(mnemonic != nil ? "SET" : "NIL")")

        // Ensure mnemonic is set before serializing
        guard let mnemonic = mnemonic, !mnemonic.isEmpty else {
            print("[HDKeyring] ❌ ERROR: Cannot serialize - mnemonic not set or empty")
            print("[HDKeyring] ❌ mnemonic is nil: \(self.mnemonic == nil)")
            print("[HDKeyring] ❌ mnemonic is empty: \(self.mnemonic?.isEmpty ?? false)")
            throw KeyringError.mnemonicNotSet
        }

        let dict: [String: Any] = [
            "mnemonic": mnemonic,
            "passphrase": passphrase,
            "numberOfAccounts": numberOfAccounts,
            "hdPath": hdPath,
            "accounts": accounts,
            "index": index
        ]
        print("[HDKeyring] 🟢 Serializing with \(numberOfAccounts) accounts, mnemonic: \(mnemonic.split(separator: " ").count) words")
        let data = try JSONSerialization.data(withJSONObject: dict)
        print("[HDKeyring] 🟢 Serialized data size: \(data.count) bytes")
        return data
    }

    func deserialize(from data: Data) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KeyringError.invalidSerializedData
        }

        // Validate mnemonic exists and is not empty
        guard let mnemonic = dict["mnemonic"] as? String, !mnemonic.isEmpty else {
            print("[HDKeyring] ERROR: Invalid deserialization - mnemonic missing or empty")
            throw KeyringError.mnemonicNotSet
        }

        self.mnemonic = mnemonic
        self.passphrase = dict["passphrase"] as? String ?? ""
        self.numberOfAccounts = dict["numberOfAccounts"] as? Int ?? 0
        self.hdPath = dict["hdPath"] as? String ?? "m/44'/60'/0'/0"
        self.accounts = dict["accounts"] as? [String] ?? []
        self.index = dict["index"] as? Int ?? 0

        let wordCount = mnemonic.split(separator: " ").count
        print("[HDKeyring] Deserialized with \(numberOfAccounts) accounts, mnemonic: \(wordCount) words")
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
        print("[KeyringManager] Verifying password...")
        let encryptedVault = try? await storageManager.getEncryptedVault()
        guard let vault = encryptedVault else {
            // No vault yet — password is accepted for new vault
            print("[KeyringManager] No vault found - accepting password for new vault")
            return true
        }
        print("[KeyringManager] Vault found, attempting to decrypt...")
        do {
            _ = try await storageManager.decrypt(data: vault, password: password)
            print("[KeyringManager] Password verified successfully")
            return true
        } catch {
            print("[KeyringManager] Password verification failed: \(error)")
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

        case .ledger:
            // Ledger keyrings are typically created through LedgerConnectView,
            // but this path supports programmatic creation as well.
            // The Ledger device must be connected via BLE before calling addAccounts.
            let ledger = LedgerKeyring()
            if let accountCount = options?["accountCount"] as? Int, accountCount > 0 {
                _ = try await ledger.addAccounts(count: accountCount)
            }
            keyring = ledger

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
        let privateKey = try KeystoreV3.decryptPrivateKey(json: json, password: password)
        let keyring = try SimpleKeyring(privateKeys: [privateKey])
        await addKeyring(keyring)
        try await persistAllKeyrings()
    }

    /// Decrypt a Keystore V3 JSON file and import the private key.
    /// - Parameters:
    ///   - jsonString: The Keystore V3 JSON string.
    ///   - password: The password used to encrypt the keystore.
    /// - Returns: The checksummed Ethereum address derived from the decrypted private key.
    @discardableResult
    func importFromKeystore(_ jsonString: String, password: String) async throws -> String {
        let privateKey = try KeystoreV3.decryptPrivateKey(json: jsonString, password: password)
        let address = try EthereumUtil.privateKeyToAddress(privateKey)

        // Check if this address already exists in any keyring
        let existingAccounts = await getAccounts()
        guard !existingAccounts.contains(where: { $0.lowercased() == address.lowercased() }) else {
            // Address already imported; return it without duplicating
            return address
        }

        let keyring = try SimpleKeyring(privateKeys: [privateKey])
        await addKeyring(keyring)
        try await persistAllKeyrings()

        return address
    }
    
    func restoreFromMnemonic(mnemonic: String, password: String) async throws {
        guard HDKeyring.validateMnemonic(mnemonic) else {
            throw KeyringError.invalidMnemonic
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
    func signAndSendTransaction(
        from: String,
        to: String?,
        value: String?,
        data: String?,
        gasLimit: String?,
        gasPrice: String?,
        maxFeePerGas: String?,
        maxPriorityFeePerGas: String?
    ) async throws -> String {
        let chain = ChainManager.shared.selectedChain ?? Chain.ethereum
        guard let to = to, !to.isEmpty else {
            throw KeyringError.invalidOptions
        }
        
        let valueHex = (value?.isEmpty ?? true) ? "0x0" : (value ?? "0x0")
        let dataHex = (data?.isEmpty ?? true) ? "0x" : (data ?? "0x")
        
        // Nonce + gas
        let nonce = try await TransactionManager.shared.getRecommendedNonce(address: from, chain: chain)
        
        let resolvedGasLimit: BigUInt
        if let gasLimit = gasLimit, !gasLimit.isEmpty, let parsed = BigUInt(gasLimit) {
            resolvedGasLimit = parsed
        } else {
            resolvedGasLimit = try await TransactionManager.shared.estimateGas(
                from: from,
                to: to,
                value: valueHex,
                data: dataHex,
                chain: chain
            )
        }
        
        var tx = EthereumTransaction(
            to: to,
            from: from,
            nonce: nonce,
            value: BigUInt(valueHex.hexToData() ?? Data()),
            data: dataHex.hexToData() ?? Data(),
            gasLimit: resolvedGasLimit,
            chainId: chain.id
        )
        
        // Fees
        if chain.supportsEIP1559 {
            let resolvedMaxFee: BigUInt
            let resolvedPriority: BigUInt
            
            if let maxFeePerGas = maxFeePerGas, !maxFeePerGas.isEmpty,
               let maxPriorityFeePerGas = maxPriorityFeePerGas, !maxPriorityFeePerGas.isEmpty,
               (Decimal(string: maxFeePerGas) != nil),
               (Decimal(string: maxPriorityFeePerGas) != nil) {
                resolvedMaxFee = EthereumUtil.gweiToWei(Decimal(string: maxFeePerGas) ?? 0)
                resolvedPriority = EthereumUtil.gweiToWei(Decimal(string: maxPriorityFeePerGas) ?? 0)
            } else {
                if let feeData = try await TransactionManager.shared.getEIP1559FeeData(chain: chain) {
                    resolvedMaxFee = feeData.maxFeePerGas
                    resolvedPriority = feeData.maxPriorityFeePerGas
                } else {
                    resolvedMaxFee = EthereumUtil.gweiToWei(30)
                    resolvedPriority = EthereumUtil.gweiToWei(2)
                }
            }
            
            tx.maxFeePerGas = resolvedMaxFee
            tx.maxPriorityFeePerGas = resolvedPriority
            tx.gasPrice = nil
        } else {
            let resolvedGasPrice: BigUInt
            if let gasPrice = gasPrice, !gasPrice.isEmpty {
                let wei = EthereumUtil.gweiToWei(Decimal(string: gasPrice) ?? 0)
                resolvedGasPrice = wei
            } else {
                resolvedGasPrice = try await TransactionManager.shared.getGasPrice(chain: chain)
            }
            tx.gasPrice = resolvedGasPrice
            tx.maxFeePerGas = nil
            tx.maxPriorityFeePerGas = nil
        }
        
        return try await TransactionManager.shared.sendTransaction(tx)
    }
    
    // MARK: - Persistence
    func persistAllKeyrings() async throws {
        print("[KeyringManager] Persisting \(keyrings.count) keyring(s)...")
        guard let password = password else {
            print("[KeyringManager] ERROR: No password available for persistence")
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
        print("[KeyringManager] Saving encrypted vault (size: \(vaultData.count) bytes)...")
        try await storageManager.saveEncryptedVault(data: vaultData, password: password)
        print("[KeyringManager] Vault saved successfully")

        // Verify vault was saved
        if let savedVault = try? await storageManager.getEncryptedVault() {
            print("[KeyringManager] ✓ Vault verification: \(savedVault.count) bytes saved")
        } else {
            print("[KeyringManager] ⚠️ WARNING: Vault verification failed!")
        }
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
            case .ledger:
                keyring = LedgerKeyring()
            default:
                continue
            }
            
            try keyring.deserialize(from: data)
            loadedKeyrings.append(keyring)
        }
        
        return loadedKeyrings
    }
}

// MARK: - Keystore (V3) Import

/// Minimal Ethereum keystore v3 decrypter (scrypt/pbkdf2 + aes-128-ctr + keccak256 mac).
/// Used by `KeyringManager.importFromKeystore`.
struct KeystoreV3 {
    static func decryptPrivateKey(json: String, password: String) throws -> Data {
        guard let jsonData = json.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw KeyringError.invalidSerializedData
        }
        
        let addressInFile = (root["address"] as? String)?
            .lowercased()
            .replacingOccurrences(of: "0x", with: "")
        
        guard let crypto = (root["crypto"] as? [String: Any]) ?? (root["Crypto"] as? [String: Any]) else {
            throw KeyringError.invalidSerializedData
        }
        
        guard let cipher = (crypto["cipher"] as? String)?.lowercased(),
              cipher == "aes-128-ctr" else {
            throw KeyringError.operationNotSupported
        }
        
        guard let cipherparams = crypto["cipherparams"] as? [String: Any],
              let ivHex = cipherparams["iv"] as? String,
              let iv = Data(hexString: ivHex),
              iv.count == 16 else {
            throw KeyringError.invalidSerializedData
        }
        
        guard let ciphertextHex = crypto["ciphertext"] as? String,
              let ciphertext = Data(hexString: ciphertextHex) else {
            throw KeyringError.invalidSerializedData
        }
        
        guard let kdf = (crypto["kdf"] as? String)?.lowercased(),
              let kdfparams = crypto["kdfparams"] as? [String: Any],
              let dklen = kdfparams["dklen"] as? Int,
              let saltHex = kdfparams["salt"] as? String,
              let salt = Data(hexString: saltHex) else {
            throw KeyringError.invalidSerializedData
        }
        
        let derivedKey: Data
        switch kdf {
        case "scrypt":
            guard let n = kdfparams["n"] as? Int,
                  let r = kdfparams["r"] as? Int,
                  let p = kdfparams["p"] as? Int else {
                throw KeyringError.invalidSerializedData
            }
            let scrypt = try Scrypt(
                password: Array(password.utf8),
                salt: [UInt8](salt),
                dkLen: dklen,
                N: n,
                r: r,
                p: p
            )
            derivedKey = Data(try scrypt.calculate())
            
        case "pbkdf2":
            // Only support hmac-sha256 for now.
            if let prf = (kdfparams["prf"] as? String)?.lowercased(), prf != "hmac-sha256" {
                throw KeyringError.operationNotSupported
            }
            guard let c = kdfparams["c"] as? Int else {
                throw KeyringError.invalidSerializedData
            }
            derivedKey = try PBKDF2.deriveKey(
                password: Data(password.utf8),
                salt: salt,
                iterations: c,
                keyLength: dklen
            )
            
        default:
            throw KeyringError.operationNotSupported
        }
        
        guard derivedKey.count >= 32 else {
            throw KeyringError.invalidSerializedData
        }
        
        // Validate MAC: keccak256(derivedKey[16..32] + ciphertext)
        let macInput = derivedKey.suffix(16) + ciphertext
        let computedMac = Keccak256.hash(data: macInput).hexString.lowercased()
        let storedMac = (crypto["mac"] as? String)?
            .lowercased()
            .replacingOccurrences(of: "0x", with: "")
        
        guard storedMac == computedMac else {
            throw KeyringError.invalidPassword
        }
        
        // Decrypt ciphertext with AES-128-CTR using derivedKey[0..16] as key.
        let aesKey = [UInt8](derivedKey.prefix(16))
        let aes = try AES(
            key: aesKey,
            blockMode: CTR(iv: [UInt8](iv)),
            padding: .noPadding
        )
        let plainBytes = try aes.decrypt([UInt8](ciphertext))
        let privateKey = Data(plainBytes)
        
        guard privateKey.count == 32 else {
            throw KeyringError.invalidSerializedData
        }
        
        // If address is present, ensure it matches the decrypted private key.
        if let expected = addressInFile, !expected.isEmpty {
            let derivedAddr = try EthereumUtil.privateKeyToAddress(privateKey)
                .lowercased()
                .replacingOccurrences(of: "0x", with: "")
            guard derivedAddr == expected else {
                throw KeyringError.invalidSerializedData
            }
        }
        
        return privateKey
    }
}

// MARK: - Errors
enum KeyringError: Error, LocalizedError {
    case invalidMnemonicStrength
    case failedToGenerateMnemonic
    case mnemonicNotSet
    case invalidMnemonic
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
        case .invalidMnemonic:
            return "Invalid seed phrase. Please check each word is a valid BIP39 word and the phrase has correct checksum."
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
