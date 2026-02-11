import Foundation
import UserNotifications
import UIKit
import Combine

/// Notification & Approval Queue Manager
/// Corresponds to: src/background/service/notification.ts (506 lines)
/// Handles DApp approval requests queue and iOS push/local notifications
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var currentApproval: ApprovalItem? = nil
    @Published var approvalQueue: [ApprovalItem] = []
    @Published var isShowingApproval = false
    @Published var notificationsEnabled = false
    
    private var dappRejectTracker: [String: DAppRejectInfo] = [:]
    
    // MARK: - Models
    
    struct ApprovalItem: Identifiable {
        let id: String
        let type: ApprovalType
        let data: ApprovalData
        let origin: String?
        let siteName: String?
        let iconUrl: String?
        var resolve: ((Any?) -> Void)?
        var reject: ((Error) -> Void)?
        let createdAt: Date
        
        enum ApprovalType: String {
            case signTx = "SignTx"
            case signText = "SignText"
            case signTypedData = "SignTypedData"
            case connect = "Connect"
            case addChain = "AddChain"
            case switchChain = "SwitchChain"
            case watchAsset = "WatchAsset"
        }
        
        struct ApprovalData {
            let params: [String: Any]?
            let account: Account?
            let chainId: Int?
        }
    }
    
    struct DAppRejectInfo {
        var lastRejectTimestamp: Date
        var rejectCount: Int
    }
    
    struct StatsData {
        var signed: Bool = false
        var signedSuccess: Bool = false
        var submit: Bool = false
        var submitSuccess: Bool = false
        var type: String = ""
        var chainId: String = ""
        var preExecSuccess: Bool = false
    }
    
    private init() {
        checkNotificationPermission()
    }
    
    // MARK: - Approval Queue Management
    
    /// Request user approval (called from DApp browser / WalletConnect)
    func requestApproval(
        type: ApprovalItem.ApprovalType,
        params: [String: Any]?,
        origin: String?,
        siteName: String?,
        iconUrl: String?,
        account: Account?,
        chainId: Int?
    ) async throws -> Any? {
        // Check if DApp is being rate-limited for spam rejections
        if let origin = origin, isDAppRateLimited(origin: origin) {
            throw NotificationError.dappRateLimited
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let item = ApprovalItem(
                id: UUID().uuidString,
                type: type,
                data: ApprovalItem.ApprovalData(params: params, account: account, chainId: chainId),
                origin: origin,
                siteName: siteName,
                iconUrl: iconUrl,
                resolve: { result in continuation.resume(returning: result) },
                reject: { error in continuation.resume(throwing: error) },
                createdAt: Date()
            )
            
            // Queue or show immediately
            if currentApproval == nil {
                currentApproval = item
                isShowingApproval = true
            } else {
                approvalQueue.append(item)
            }
            
            // Send local notification if app is in background
            sendLocalNotification(
                title: "Approval Request",
                body: "\(siteName ?? origin ?? "DApp") requests \(type.rawValue)"
            )
        }
    }
    
    /// Resolve current approval
    func resolveApproval(data: Any? = nil) {
        currentApproval?.resolve?(data)
        advanceQueue()
    }
    
    /// Reject current approval
    func rejectApproval(error: Error? = nil) {
        let err = error ?? NotificationError.userRejected
        currentApproval?.reject?(err)
        
        // Track rejection for rate limiting
        if let origin = currentApproval?.origin {
            trackRejection(origin: origin)
        }
        
        advanceQueue()
    }
    
    /// Clear all pending approvals
    func rejectAllApprovals() {
        let err = NotificationError.userRejected
        currentApproval?.reject?(err)
        for item in approvalQueue {
            item.reject?(err)
        }
        approvalQueue.removeAll()
        currentApproval = nil
        isShowingApproval = false
    }
    
    private func advanceQueue() {
        currentApproval = nil
        if !approvalQueue.isEmpty {
            currentApproval = approvalQueue.removeFirst()
            isShowingApproval = true
        } else {
            isShowingApproval = false
        }
    }
    
    // MARK: - DApp Rate Limiting
    
    private func isDAppRateLimited(origin: String) -> Bool {
        guard let info = dappRejectTracker[origin] else { return false }
        let timeSinceLastReject = Date().timeIntervalSince(info.lastRejectTimestamp)
        // If rejected 5+ times within 30 seconds, rate limit
        return info.rejectCount >= 5 && timeSinceLastReject < 30
    }
    
    private func trackRejection(origin: String) {
        var info = dappRejectTracker[origin] ?? DAppRejectInfo(lastRejectTimestamp: Date(), rejectCount: 0)
        let timeSince = Date().timeIntervalSince(info.lastRejectTimestamp)
        if timeSince > 30 { info.rejectCount = 0 }
        info.rejectCount += 1
        info.lastRejectTimestamp = Date()
        dappRejectTracker[origin] = info
    }
    
    // MARK: - iOS Push/Local Notifications
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Task { @MainActor in self.notificationsEnabled = granted }
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func sendLocalNotification(title: String, body: String) {
        guard notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Send notification for transaction status
    func notifyTransactionStatus(hash: String, success: Bool) {
        sendLocalNotification(
            title: success ? "Transaction Confirmed" : "Transaction Failed",
            body: "Tx: \(hash.prefix(10))...\(hash.suffix(6))"
        )
    }
    
    /// Send notification for swap completion
    func notifySwapComplete(fromSymbol: String, toSymbol: String, success: Bool) {
        sendLocalNotification(
            title: success ? "Swap Complete" : "Swap Failed",
            body: "\(fromSymbol) → \(toSymbol)"
        )
    }
    
    /// Send notification for bridge completion
    func notifyBridgeComplete(fromChain: String, toChain: String, success: Bool) {
        sendLocalNotification(
            title: success ? "Bridge Complete" : "Bridge Failed",
            body: "\(fromChain) → \(toChain)"
        )
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount() {
        let count = approvalQueue.count + (currentApproval != nil ? 1 : 0)
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    func clearBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}

// MARK: - Errors

enum NotificationError: LocalizedError {
    case userRejected
    case dappRateLimited
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .userRejected: return "User rejected the request"
        case .dappRateLimited: return "Too many requests from this DApp"
        case .timeout: return "Request timed out"
        }
    }
}
