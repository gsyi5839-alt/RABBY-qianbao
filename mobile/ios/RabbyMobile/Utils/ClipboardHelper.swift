import UIKit
import UniformTypeIdentifiers
import MobileCoreServices

/// Enhanced clipboard helper for iOS 16+ privacy support
@MainActor
class ClipboardHelper {

    /// Result of clipboard read operation
    enum ReadResult {
        case success(String)
        case empty
        case permissionDenied
        case error(Error)
    }

    /// Force trigger clipboard permission prompt and read content
    /// This is a workaround for iOS 16+ cross-app paste restrictions
    static func forceReadClipboard() async -> ReadResult {
        let pasteboard = UIPasteboard.general

        // Method 1: Try direct access first (triggers permission if needed)
        if let string = pasteboard.string {
            if !string.isEmpty {
                return .success(string)
            }
        }

        // Method 2: Try all registered type identifiers
        for typeIdentifier in preferredTypeIdentifiers() {
            if pasteboard.hasStrings || pasteboard.contains(pasteboardTypes: [typeIdentifier]) {
                if let value = pasteboard.value(forPasteboardType: typeIdentifier) {
                    if let text = parseValue(value) {
                        return .success(text)
                    }
                }

                if let data = pasteboard.data(forPasteboardType: typeIdentifier) {
                    if let text = parseValue(data) {
                        return .success(text)
                    }
                }
            }
        }

        // Method 3: Try item providers (iOS 14+)
        let providers = pasteboard.itemProviders
        for provider in providers {
            for typeIdentifier in preferredTypeIdentifiers() {
                if provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                    if let item = await loadItem(from: provider, typeIdentifier: typeIdentifier) {
                        if let text = parseValue(item) {
                            return .success(text)
                        }
                    }
                }
            }
        }

        // Method 4: Check all items
        if let strings = pasteboard.strings {
            if let first = strings.first, !first.isEmpty {
                return .success(first)
            }
        }

        // Determine failure reason
        if pasteboard.hasStrings || !pasteboard.itemProviders.isEmpty {
            return .permissionDenied
        }

        return .empty
    }

    /// Read clipboard with automatic retry for mnemonic phrases
    /// Retries up to 8 times with 200ms delay to handle iOS permission dialogs
    static func readMnemonicWithRetry(maxAttempts: Int = 8) async -> ReadResult {
        var lastResult: ReadResult = .empty

        for attempt in 0..<maxAttempts {
            let result = await forceReadClipboard()
            lastResult = result

            // If we got valid text with multiple words, return immediately
            if case .success(let text) = result {
                let wordCount = text
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .count

                if wordCount > 1 {
                    return result
                }
            }

            // Wait before retry (except last attempt)
            if attempt < maxAttempts - 1 {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        }

        return lastResult
    }

    /// Write text to clipboard
    static func write(_ text: String) {
        UIPasteboard.general.string = text
    }

    /// Check if clipboard has content (doesn't trigger permission)
    static func hasContent() -> Bool {
        let pasteboard = UIPasteboard.general
        return pasteboard.hasStrings || !pasteboard.itemProviders.isEmpty
    }

    // MARK: - Private Helpers

    private static func preferredTypeIdentifiers() -> [String] {
        [
            UTType.utf8PlainText.identifier,
            UTType.plainText.identifier,
            UTType.text.identifier,
            "public.utf8-plain-text",
            "public.plain-text",
            "public.text",
            kUTTypeUTF8PlainText as String,
            kUTTypePlainText as String,
            kUTTypeText as String
        ]
    }

    private static func parseValue(_ value: Any) -> String? {
        if let text = value as? String {
            return normalizeText(text)
        }
        if let attributed = value as? NSAttributedString {
            return normalizeText(attributed.string)
        }
        if let data = value as? Data {
            if let utf8 = String(data: data, encoding: .utf8) {
                return normalizeText(utf8)
            }
            if let utf16 = String(data: data, encoding: .utf16) {
                return normalizeText(utf16)
            }
            if let unicode = String(data: data, encoding: .unicode) {
                return normalizeText(unicode)
            }
        }
        if let url = value as? URL {
            return normalizeText(url.absoluteString)
        }
        return nil
    }

    private static func loadItem(from provider: NSItemProvider, typeIdentifier: String) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }

    private static func normalizeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ") // Non-breaking space
            .replacingOccurrences(of: "\u{3000}", with: " ") // Ideographic space
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// Enhanced paste button with better cross-app support
struct EnhancedPasteButton: View {
    let label: String
    let onPaste: (String) -> Void
    let onError: (String) -> Void

    @State private var isLoading = false

    init(
        label: String = "Paste",
        onPaste: @escaping (String) -> Void,
        onError: @escaping (String) -> Void = { _ in }
    ) {
        self.label = label
        self.onPaste = onPaste
        self.onError = onError
    }

    var body: some View {
        Button(action: handlePaste) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "doc.on.clipboard")
                }
                Text(label)
            }
            .font(.caption)
        }
        .disabled(isLoading)
    }

    private func handlePaste() {
        isLoading = true

        Task {
            let result = await ClipboardHelper.forceReadClipboard()

            await MainActor.run {
                isLoading = false

                switch result {
                case .success(let text):
                    onPaste(text)

                case .empty:
                    onError("剪贴板为空，请先复制内容")

                case .permissionDenied:
                    onError("粘贴被iOS阻止。请前往 设置 > Rabby Wallet > 从其他App粘贴 并设置为\"允许\"")

                case .error(let error):
                    onError("粘贴失败：\(error.localizedDescription)")
                }
            }
        }
    }
}
