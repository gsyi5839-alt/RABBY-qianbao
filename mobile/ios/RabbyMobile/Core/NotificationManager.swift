import Foundation
import UserNotifications
import UIKit
import Combine

/// Notification & Approval Queue Manager
/// Corresponds to: src/background/service/notification.ts (506 lines)
/// Handles DApp approval requests queue and iOS push/local notifications
///
/// Integration with TransactionWatcherManager:
/// ─────────────────────────────────────────────
/// In TransactionWatcherManager.checkTransaction(hash:), when the receipt arrives:
///
///   if let receipt = receipt {
///       let success = (receipt["status"] as? String) == "0x1"
///       if success {
///           NotificationManager.shared.notifyTransactionConfirmed(
///               hash: hash,
///               description: "Transaction on \(tx.chain)"
///           )
///       } else {
///           NotificationManager.shared.notifyTransactionFailed(
///               hash: hash,
///               reason: "Reverted on chain"
///           )
///       }
///       NotificationManager.shared.decrementPendingBadge()
///   }
///
/// In TransactionWatcherManager.watchTransaction(hash:chain:nonce:address:):
///   NotificationManager.shared.notifyTransactionSubmitted(
///       hash: hash, type: "send", chainName: chain
///   )
///   NotificationManager.shared.incrementPendingBadge()
///
/// For pending timeout detection, TransactionWatcherManager.checkTransaction
/// should check elapsed time:
///   let elapsed = Date().timeIntervalSince(tx.createdAt)
///   if elapsed > 600 && !tx.timeoutNotified {
///       NotificationManager.shared.notifyPendingTimeout(
///           hash: hash,
///           minutes: Int(elapsed / 60)
///       )
///       tx.timeoutNotified = true
///   }
///
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    // MARK: - Published State

    @Published var currentApproval: ApprovalItem? = nil
    @Published var approvalQueue: [ApprovalItem] = []
    @Published var isShowingApproval = false
    @Published var notificationsEnabled = false
    @Published var notificationSettings = NotificationPreferences()

    // MARK: - Private State

    private var dappRejectTracker: [String: DAppRejectInfo] = [:]
    private var pendingBadgeCount: Int = 0
    private let storage = StorageManager.shared
    private let notificationSettingsKey = "rabby_notification_settings"

    // MARK: - Notification Category Identifiers

    /// Category for transaction-related notifications.
    /// Actions: VIEW (view transaction details), SPEED_UP (speed up pending tx)
    static let transactionCategoryIdentifier = "TRANSACTION"

    /// Category for DApp approval request notifications.
    /// Actions: APPROVE (approve request), REJECT (reject request)
    static let approvalCategoryIdentifier = "APPROVAL"

    // MARK: - Notification Action Identifiers

    static let viewActionIdentifier = "VIEW"
    static let speedUpActionIdentifier = "SPEED_UP"
    static let approveActionIdentifier = "APPROVE"
    static let rejectActionIdentifier = "REJECT"

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

    /// User-configurable notification preferences, persisted via StorageManager.
    struct NotificationPreferences: Codable {
        var transactionConfirmed: Bool = true
        var transactionFailed: Bool = true
        var pendingTimeout: Bool = true
        var dappRequests: Bool = true
    }

    // MARK: - Initialization

    private init() {
        checkNotificationPermission()
        registerNotificationCategories()
        loadNotificationSettings()
    }

    // MARK: - Notification Categories (UNNotificationCategory)

    /// Register notification categories and their associated actions.
    ///
    /// "TRANSACTION" category:
    ///   - "VIEW"     : View transaction details in the app
    ///   - "SPEED_UP" : Speed up a pending transaction (only meaningful for pending txs)
    ///
    /// "APPROVAL" category:
    ///   - "APPROVE" : Approve the DApp request
    ///   - "REJECT"  : Reject the DApp request
    private func registerNotificationCategories() {
        // TRANSACTION category actions
        let viewAction = UNNotificationAction(
            identifier: Self.viewActionIdentifier,
            title: "View Details",
            options: [.foreground]
        )
        let speedUpAction = UNNotificationAction(
            identifier: Self.speedUpActionIdentifier,
            title: "Speed Up",
            options: [.foreground]
        )
        let transactionCategory = UNNotificationCategory(
            identifier: Self.transactionCategoryIdentifier,
            actions: [viewAction, speedUpAction],
            intentIdentifiers: [],
            options: []
        )

        // APPROVAL category actions
        let approveAction = UNNotificationAction(
            identifier: Self.approveActionIdentifier,
            title: "Approve",
            options: [.foreground]
        )
        let rejectAction = UNNotificationAction(
            identifier: Self.rejectActionIdentifier,
            title: "Reject",
            options: [.destructive]
        )
        let approvalCategory = UNNotificationCategory(
            identifier: Self.approvalCategoryIdentifier,
            actions: [approveAction, rejectAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            transactionCategory,
            approvalCategory
        ])
    }

    // MARK: - Notification Settings (Persisted to PreferenceManager)

    /// Load user notification preferences from storage.
    private func loadNotificationSettings() {
        if let data = storage.getData(forKey: notificationSettingsKey),
           let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            self.notificationSettings = prefs
        }
    }

    /// Save user notification preferences to storage.
    private func saveNotificationSettings() {
        if let data = try? JSONEncoder().encode(notificationSettings) {
            storage.setData(data, forKey: notificationSettingsKey)
        }
    }

    /// Update whether transaction confirmed notifications are enabled.
    func setTransactionConfirmedEnabled(_ enabled: Bool) {
        notificationSettings.transactionConfirmed = enabled
        saveNotificationSettings()
    }

    /// Update whether transaction failed notifications are enabled.
    func setTransactionFailedEnabled(_ enabled: Bool) {
        notificationSettings.transactionFailed = enabled
        saveNotificationSettings()
    }

    /// Update whether pending timeout notifications are enabled.
    func setPendingTimeoutEnabled(_ enabled: Bool) {
        notificationSettings.pendingTimeout = enabled
        saveNotificationSettings()
    }

    /// Update whether DApp request notifications are enabled.
    func setDappRequestsEnabled(_ enabled: Bool) {
        notificationSettings.dappRequests = enabled
        saveNotificationSettings()
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

            // Send local notification for DApp approval request if enabled
            if notificationSettings.dappRequests {
                notifyApprovalRequest(
                    dappName: siteName ?? origin ?? "DApp",
                    type: type.rawValue
                )
            }
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

    // MARK: - iOS Push/Local Notifications (Core Delivery)

    /// Request notification permission from the user.
    /// On first invocation, iOS shows the system permission dialog.
    /// If previously denied, guide the user to Settings.
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .notDetermined:
                    // First time: iOS will show the system permission dialog
                    do {
                        let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                            options: [.alert, .badge, .sound]
                        )
                        self?.notificationsEnabled = granted
                    } catch {
                        self?.notificationsEnabled = false
                    }

                case .denied:
                    // Previously denied: guide user to Settings
                    self?.openSystemNotificationSettings()

                case .authorized, .provisional, .ephemeral:
                    self?.notificationsEnabled = true

                @unknown default:
                    break
                }
            }
        }
    }

    /// Open the iOS Settings app to the notification settings page for this app.
    /// Called when the user has previously denied notification permission.
    private func openSystemNotificationSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
        }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    /// Core method: send a local notification with a given category.
    /// All public notify* methods funnel through this.
    private func sendLocalNotification(
        title: String,
        body: String,
        categoryIdentifier: String? = nil,
        userInfo: [String: Any] = [:],
        threadIdentifier: String? = nil
    ) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let category = categoryIdentifier {
            content.categoryIdentifier = category
        }

        if !userInfo.isEmpty {
            content.userInfo = userInfo
        }

        if let thread = threadIdentifier {
            content.threadIdentifier = thread
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Transaction Status Notifications

    /// Notify that a transaction has been submitted to the network.
    /// Displayed as an informational notification.
    ///
    /// - Parameters:
    ///   - hash: The transaction hash
    ///   - type: Transaction type (e.g. "send", "swap", "bridge", "approve")
    ///   - chainName: Human-readable chain name (e.g. "Ethereum", "Arbitrum")
    func notifyTransactionSubmitted(hash: String, type: String, chainName: String) {
        let shortHash = formatHash(hash)
        sendLocalNotification(
            title: "Transaction submitted",
            body: "\(type.capitalized) on \(chainName) (\(shortHash))",
            categoryIdentifier: Self.transactionCategoryIdentifier,
            userInfo: [
                "type": "transaction_submitted",
                "hash": hash,
                "txType": type,
                "chain": chainName
            ],
            threadIdentifier: "tx_\(hash)"
        )
    }

    /// Notify that a transaction has been confirmed on-chain.
    /// Displayed as a success notification. Respects user preference.
    ///
    /// - Parameters:
    ///   - hash: The transaction hash
    ///   - description: A human-readable description of the transaction
    func notifyTransactionConfirmed(hash: String, description: String) {
        guard notificationSettings.transactionConfirmed else { return }

        let shortHash = formatHash(hash)
        sendLocalNotification(
            title: "Transaction confirmed \u{2713}",
            body: "\(description) (\(shortHash))",
            categoryIdentifier: Self.transactionCategoryIdentifier,
            userInfo: [
                "type": "transaction_confirmed",
                "hash": hash
            ],
            threadIdentifier: "tx_\(hash)"
        )
    }

    /// Notify that a transaction has failed on-chain.
    /// Displayed as an error notification. Respects user preference.
    ///
    /// - Parameters:
    ///   - hash: The transaction hash
    ///   - reason: Optional failure reason string
    func notifyTransactionFailed(hash: String, reason: String?) {
        guard notificationSettings.transactionFailed else { return }

        let shortHash = formatHash(hash)
        let body: String
        if let reason = reason, !reason.isEmpty {
            body = "\(shortHash): \(reason)"
        } else {
            body = "Transaction \(shortHash) did not succeed"
        }

        sendLocalNotification(
            title: "Transaction failed \u{2715}",
            body: body,
            categoryIdentifier: Self.transactionCategoryIdentifier,
            userInfo: [
                "type": "transaction_failed",
                "hash": hash,
                "reason": reason ?? ""
            ],
            threadIdentifier: "tx_\(hash)"
        )
    }

    /// Notify that a swap has completed successfully.
    /// Displayed as a success notification.
    ///
    /// - Parameters:
    ///   - fromToken: Source token symbol and amount (e.g. "1 ETH")
    ///   - toToken: Destination token symbol and amount (e.g. "3000 USDC")
    ///   - amount: The amount swapped (included in body for clarity)
    func notifySwapCompleted(fromToken: String, toToken: String, amount: String) {
        guard notificationSettings.transactionConfirmed else { return }

        sendLocalNotification(
            title: "Swap completed \u{2713}",
            body: "Swap completed: \(amount) \(fromToken) \u{2192} \(toToken)",
            categoryIdentifier: Self.transactionCategoryIdentifier,
            userInfo: [
                "type": "swap_completed",
                "fromToken": fromToken,
                "toToken": toToken,
                "amount": amount
            ],
            threadIdentifier: "tx_swap"
        )
    }

    /// Notify that a bridge transfer has completed and tokens arrived on the destination chain.
    /// Displayed as a success notification.
    ///
    /// - Parameters:
    ///   - token: The token symbol and amount that was bridged (e.g. "1 ETH")
    ///   - toChain: The destination chain name (e.g. "Arbitrum")
    func notifyBridgeCompleted(token: String, toChain: String) {
        guard notificationSettings.transactionConfirmed else { return }

        sendLocalNotification(
            title: "Bridge completed \u{2713}",
            body: "Bridge completed: \(token) arrived on \(toChain)",
            categoryIdentifier: Self.transactionCategoryIdentifier,
            userInfo: [
                "type": "bridge_completed",
                "token": token,
                "toChain": toChain
            ],
            threadIdentifier: "tx_bridge"
        )
    }

    /// Notify that a pending transaction has been waiting for longer than expected.
    /// Triggered when a transaction remains pending for >10 minutes. Respects user preference.
    ///
    /// - Parameters:
    ///   - hash: The transaction hash
    ///   - minutes: Number of minutes the transaction has been pending
    func notifyPendingTimeout(hash: String, minutes: Int) {
        guard notificationSettings.pendingTimeout else { return }

        let shortHash = formatHash(hash)
        sendLocalNotification(
            title: "Transaction pending for \(minutes)+ minutes",
            body: "Transaction \(shortHash) is still pending. You may want to speed up or cancel it.",
            categoryIdentifier: Self.transactionCategoryIdentifier,
            userInfo: [
                "type": "pending_timeout",
                "hash": hash,
                "minutes": minutes
            ],
            threadIdentifier: "tx_\(hash)"
        )
    }

    /// Notify the user about an incoming DApp approval request.
    /// Shown when the app is in the background and a DApp requests approval.
    /// Respects user preference for DApp request notifications.
    ///
    /// - Parameters:
    ///   - dappName: The name (or origin) of the requesting DApp
    ///   - type: The approval type (e.g. "SignTx", "Connect")
    func notifyApprovalRequest(dappName: String, type: String) {
        guard notificationSettings.dappRequests else { return }

        sendLocalNotification(
            title: "Approval Request",
            body: "\(dappName) requests \(type)",
            categoryIdentifier: Self.approvalCategoryIdentifier,
            userInfo: [
                "type": "approval_request",
                "dappName": dappName,
                "approvalType": type
            ],
            threadIdentifier: "approval_\(dappName)"
        )
    }

    // MARK: - Legacy Convenience Methods (kept for backward compatibility)

    /// Send notification for transaction status (legacy interface)
    func notifyTransactionStatus(hash: String, success: Bool) {
        if success {
            notifyTransactionConfirmed(hash: hash, description: "Transaction")
        } else {
            notifyTransactionFailed(hash: hash, reason: nil)
        }
    }

    /// Send notification for swap completion (legacy interface)
    func notifySwapComplete(fromSymbol: String, toSymbol: String, success: Bool) {
        if success {
            notifySwapCompleted(fromToken: fromSymbol, toToken: toSymbol, amount: "")
        } else {
            notifyTransactionFailed(hash: "", reason: "Swap \(fromSymbol) \u{2192} \(toSymbol) failed")
        }
    }

    /// Send notification for bridge completion (legacy interface)
    func notifyBridgeComplete(fromChain: String, toChain: String, success: Bool) {
        if success {
            notifyBridgeCompleted(token: fromChain, toChain: toChain)
        } else {
            notifyTransactionFailed(hash: "", reason: "Bridge \(fromChain) \u{2192} \(toChain) failed")
        }
    }

    // MARK: - Badge Management

    /// Increment the badge count when a new pending transaction is submitted.
    func incrementPendingBadge() {
        pendingBadgeCount += 1
        updateBadgeCount()
    }

    /// Decrement the badge count when a pending transaction completes (confirmed or failed).
    func decrementPendingBadge() {
        pendingBadgeCount = max(0, pendingBadgeCount - 1)
        updateBadgeCount()
    }

    /// Update the app icon badge to reflect current pending items.
    /// Badge = pending transactions + pending approval queue items.
    func updateBadgeCount() {
        let approvalCount = approvalQueue.count + (currentApproval != nil ? 1 : 0)
        let totalCount = pendingBadgeCount + approvalCount

        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(totalCount)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = totalCount
        }
    }

    /// Clear all badges. Should be called when the app is opened / becomes active.
    func clearBadge() {
        pendingBadgeCount = 0
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    // MARK: - Helpers

    /// Format a transaction hash for display: "0x1234ab...cd5678"
    private func formatHash(_ hash: String) -> String {
        guard hash.count > 16 else { return hash }
        return "\(hash.prefix(8))...\(hash.suffix(6))"
    }
}

// MARK: - UNUserNotificationCenterDelegate Support
//
// The app's AppDelegate or SceneDelegate should conform to
// UNUserNotificationCenterDelegate and handle notification actions:
//
//   func userNotificationCenter(
//       _ center: UNUserNotificationCenter,
//       didReceive response: UNNotificationResponse,
//       withCompletionHandler completionHandler: @escaping () -> Void
//   ) {
//       let actionIdentifier = response.actionIdentifier
//       let userInfo = response.notification.request.content.userInfo
//
//       switch actionIdentifier {
//       case NotificationManager.viewActionIdentifier:
//           // Navigate to transaction detail screen
//           if let hash = userInfo["hash"] as? String {
//               // router.push(.transactionDetail(hash: hash))
//           }
//
//       case NotificationManager.speedUpActionIdentifier:
//           // Open speed-up flow for the pending transaction
//           if let hash = userInfo["hash"] as? String {
//               // router.push(.speedUpTransaction(hash: hash))
//           }
//
//       case NotificationManager.approveActionIdentifier:
//           // Approve the current DApp request
//           Task { @MainActor in
//               NotificationManager.shared.resolveApproval(data: nil)
//           }
//
//       case NotificationManager.rejectActionIdentifier:
//           // Reject the current DApp request
//           Task { @MainActor in
//               NotificationManager.shared.rejectApproval()
//           }
//
//       default:
//           break
//       }
//
//       completionHandler()
//   }

// MARK: - Errors

enum NotificationError: LocalizedError {
    case userRejected
    case dappRateLimited
    case timeout
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .userRejected: return "User rejected the request"
        case .dappRateLimited: return "Too many requests from this DApp"
        case .timeout: return "Request timed out"
        case .permissionDenied: return "Notification permission denied. Please enable in Settings."
        }
    }
}
