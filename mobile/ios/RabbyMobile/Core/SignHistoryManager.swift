import Foundation
import Combine

/// Sign History Manager - Track all signature operations
/// Equivalent to Web version's signTextHistory.ts
@MainActor
class SignHistoryManager: ObservableObject {
    static let shared = SignHistoryManager()
    
    @Published var signHistory: [SignHistoryItem] = []
    
    private let storage = StorageManager.shared
    private let historyKey = "rabby_sign_history"
    private let maxHistoryCount = 100
    
    // MARK: - Models
    
    struct SignHistoryItem: Codable, Identifiable {
        let id: String
        let type: SignType
        let address: String
        let chainId: String
        let message: String
        let signature: String?
        let status: SignStatus
        let timestamp: Date
        let dappInfo: DappInfo?
        
        struct DappInfo: Codable {
            let name: String
            let origin: String
            let icon: String?
        }
    }
    
    enum SignType: String, Codable {
        case personalSign = "personal_sign"
        case signTypedData = "eth_signTypedData"
        case signTypedDataV3 = "eth_signTypedData_v3"
        case signTypedDataV4 = "eth_signTypedData_v4"
        case transaction = "eth_sendTransaction"
    }
    
    enum SignStatus: String, Codable {
        case pending
        case signed
        case rejected
        case failed
    }
    
    // MARK: - Initialization
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    /// Add new sign history item
    func addSignHistory(
        type: SignType,
        address: String,
        chainId: String,
        message: String,
        signature: String? = nil,
        status: SignStatus = .pending,
        dappName: String? = nil,
        dappOrigin: String? = nil
    ) {
        let dappInfo = (dappName != nil && dappOrigin != nil) ? SignHistoryItem.DappInfo(
            name: dappName!,
            origin: dappOrigin!,
            icon: nil
        ) : nil
        
        let item = SignHistoryItem(
            id: UUID().uuidString,
            type: type,
            address: address.lowercased(),
            chainId: chainId,
            message: message,
            signature: signature,
            status: status,
            timestamp: Date(),
            dappInfo: dappInfo
        )
        
        signHistory.insert(item, at: 0)
        
        // Keep only recent items
        if signHistory.count > maxHistoryCount {
            signHistory = Array(signHistory.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    /// Update sign history status
    func updateSignStatus(id: String, status: SignStatus, signature: String? = nil) {
        guard let index = signHistory.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        var item = signHistory[index]
        item = SignHistoryItem(
            id: item.id,
            type: item.type,
            address: item.address,
            chainId: item.chainId,
            message: item.message,
            signature: signature ?? item.signature,
            status: status,
            timestamp: item.timestamp,
            dappInfo: item.dappInfo
        )
        
        signHistory[index] = item
        saveHistory()
    }
    
    /// Get sign history for specific address
    func getHistory(for address: String) -> [SignHistoryItem] {
        return signHistory.filter { $0.address.lowercased() == address.lowercased() }
    }
    
    /// Get sign history for specific chain
    func getHistory(chainId: String) -> [SignHistoryItem] {
        return signHistory.filter { $0.chainId == chainId }
    }
    
    /// Get sign history by type
    func getHistory(type: SignType) -> [SignHistoryItem] {
        return signHistory.filter { $0.type == type }
    }
    
    /// Clear all sign history
    func clearHistory() {
        signHistory.removeAll()
        saveHistory()
    }
    
    /// Clear sign history for specific address
    func clearHistory(for address: String) {
        signHistory.removeAll { $0.address.lowercased() == address.lowercased() }
        saveHistory()
    }
    
    /// Get recent sign history (last N items)
    func getRecentHistory(count: Int = 10) -> [SignHistoryItem] {
        return Array(signHistory.prefix(count))
    }
    
    // MARK: - Private Methods
    
    private func loadHistory() {
        if let data = storage.getData(forKey: historyKey),
           let history = try? JSONDecoder().decode([SignHistoryItem].self, from: data) {
            signHistory = history
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(signHistory) {
            storage.setData(data, forKey: historyKey)
        }
    }
}
