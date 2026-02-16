import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

/// Forgot Password View
/// Corresponds to: src/ui/views/ForgotPassword/
struct ForgotPasswordView: View {
    @StateObject private var keyringManager = KeyringManager.shared
    @State private var seedPhrase = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var pasteHintMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text(L("You can only reset your password if you have your seed phrase. This will restore your wallet with the new password."))
                            .font(.subheadline).foregroundColor(.orange)
                    }
                    .padding().background(Color.orange.opacity(0.1)).cornerRadius(8)
                    
                    // Seed phrase
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L("Enter Seed Phrase")).font(.headline)
                            Spacer()
                            if #available(iOS 16.0, *) {
                                PasteButton(payloadType: String.self) { values in
                                    applyPastedSeedPhrase(values.joined(separator: " "))
                                }
                                .font(.caption)
                            } else {
                                Button(action: pasteSeedPhraseFromClipboard) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.clipboard")
                                        Text(L("Paste"))
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                        NoSuggestionSeedTextEditor(text: $seedPhrase)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        Text(L("Enter your 12 or 24 word seed phrase, separated by spaces"))
                            .font(.caption).foregroundColor(.secondary)

                        if let pasteHintMessage, !pasteHintMessage.isEmpty {
                            Text(pasteHintMessage)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // New password
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("New Password")).font(.headline)
                        SecureField(L("Enter new password"), text: $newPassword)
                            .textFieldStyle(.roundedBorder)
                        SecureField(L("Confirm new password"), text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                        
                        if newPassword.count > 0 && newPassword.count < 8 {
                            Text(L("Password must be at least 8 characters")).font(.caption).foregroundColor(.red)
                        }
                        if !confirmPassword.isEmpty && newPassword != confirmPassword {
                            Text(L("Passwords do not match")).font(.caption).foregroundColor(.red)
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                    
                    // Restore button
                    Button(action: restoreWallet) {
                        if isRestoring {
                            HStack { ProgressView().tint(.white); Text(L("Restoring...")) }
                        } else {
                            Text(L("Reset Password & Restore"))
                        }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(isValid ? Color.blue : Color.gray)
                    .foregroundColor(.white).cornerRadius(12)
                    .disabled(!isValid || isRestoring)
                }
                .padding()
            }
            .navigationTitle(L("Forgot Password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
            }
            .alert(L("Wallet Restored"), isPresented: $showSuccess) {
                Button(L("OK")) { dismiss() }
            } message: {
                Text(L("Your wallet has been restored with the new password."))
            }
        }
    }
    
    private var isValid: Bool {
        !normalizeMnemonic(seedPhrase).isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
    }

    private func pasteSeedPhraseFromClipboard() {
        Task { @MainActor in
            switch await readMnemonicClipboardWithRetry() {
            case .success(let text):
                applyPastedSeedPhrase(text)
            case .empty:
                pasteHintMessage = clipboardEmptyHint()
            case .permissionDenied:
                pasteHintMessage = clipboardPermissionDeniedHint()
            }
        }
    }

    private func applyPastedSeedPhrase(_ raw: String) {
        let normalized = normalizeMnemonic(raw)
        seedPhrase = normalized
        pasteHintMessage = mnemonicWordCount(normalized) > 1
            ? nil
            : "Clipboard currently has only one word. In Simulator use Edit > Paste, then tap Paste again."
    }
    
    private func restoreWallet() {
        isRestoring = true; errorMessage = nil
        Task {
            do {
                try await keyringManager.restoreFromMnemonic(
                    mnemonic: normalizeMnemonic(seedPhrase),
                    password: newPassword
                )
                showSuccess = true
            } catch { errorMessage = error.localizedDescription }
            isRestoring = false
        }
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
}

private struct NoSuggestionSeedTextEditor: UIViewRepresentable {
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
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.text = next
            }
        }
    }
}

/// Signed Text History View
/// Corresponds to: src/ui/views/SignedTextHistory/
struct SignedTextHistoryView: View {
    @StateObject private var signHistory = SignHistoryManager.shared
    @StateObject private var keyringManager = KeyringManager.shared
    
    var body: some View {
        Group {
            if records.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "signature").font(.system(size: 48)).foregroundColor(.gray)
                    Text(L("No signed messages")).foregroundColor(.secondary)
                    Text(L("Messages you sign from DApps will appear here")).font(.caption).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(records) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(record.type.rawValue).font(.caption).fontWeight(.semibold)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(typeColor(record.type).opacity(0.2))
                                .foregroundColor(typeColor(record.type))
                                .cornerRadius(4)
                            Spacer()
                            Text(record.timestamp, style: .relative).font(.caption2).foregroundColor(.secondary)
                        }
                        
                        if let dappInfo = record.dappInfo {
                            Text(dappInfo.origin).font(.caption).foregroundColor(.blue)
                        }
                        
                        Text(record.message.prefix(200) + (record.message.count > 200 ? "..." : ""))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(L("Signed Messages"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !records.isEmpty {
                    Button(L("Clear All")) { clearHistory() }.foregroundColor(.red)
                }
            }
        }
    }
    
    private var records: [SignHistoryManager.SignHistoryItem] {
        guard let address = keyringManager.currentAccount?.address else { return [] }
        return signHistory.getHistory(for: address)
    }
    
    private func typeColor(_ type: SignHistoryManager.SignType) -> Color {
        switch type {
        case .personalSign: return .blue
        case .signTypedData: return .purple
        case .signTypedDataV3: return .orange
        case .signTypedDataV4: return .green
        case .transaction: return .red
        }
    }
    
    private func clearHistory() {
        guard let address = keyringManager.currentAccount?.address else { return }
        signHistory.clearHistory(for: address)
    }
}
