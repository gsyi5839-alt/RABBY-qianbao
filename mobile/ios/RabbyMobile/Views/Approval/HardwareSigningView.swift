import SwiftUI

/// Hardware wallet signing wait/progress UI
/// Supports: Ledger BLE, QR-based signing, WatchOnly co-signer
struct HardwareSigningView: View {
    @Environment(\.dismiss) var dismiss

    enum DeviceType: String {
        case ledger, qrCode, watchOnly

        var icon: String {
            switch self {
            case .ledger: return "externaldrive.connected.to.line.below.fill"
            case .qrCode: return "qrcode.viewfinder"
            case .watchOnly: return "eye.fill"
            }
        }

        var displayName: String {
            switch self {
            case .ledger: return "Ledger"
            case .qrCode: return "QR Code"
            case .watchOnly: return "Watch Only"
            }
        }
    }

    enum SigningStep: Int, CaseIterable {
        case connect = 0, review, confirm, done

        var label: String {
            switch self {
            case .connect: return "Connect"
            case .review: return "Review"
            case .confirm: return "Confirm"
            case .done: return "Done"
            }
        }
    }

    enum SigningState {
        case connecting, waitingConfirm, signing, completed, error(String), timeout
    }

    let deviceType: DeviceType
    let transactionSummary: String
    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?
    var onComplete: ((String) -> Void)?

    @State private var state: SigningState = .connecting
    @State private var currentStep: SigningStep = .connect
    @State private var timeElapsed: TimeInterval = 0
    @State private var timer: Timer?

    private let timeoutDuration: TimeInterval = 60

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Device icon with animation
                deviceIconView

                // Status text
                statusTextView

                // Progress steps
                progressStepsView

                Spacer()

                // Action buttons
                actionButtonsView
            }
            .padding()
            .navigationTitle(L("Hardware Signing"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel")) { cancelSigning() }
                }
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Device Icon

    private var deviceIconView: some View {
        ZStack {
            Circle()
                .fill(stateColor.opacity(0.1))
                .frame(width: 120, height: 120)

            if case .completed = state {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            } else if case .error = state {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
            } else {
                Image(systemName: deviceType.icon)
                    .font(.system(size: 48))
                    .foregroundColor(stateColor)
                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
            }
        }
        .onAppear { isAnimating = true }
    }

    @State private var isAnimating = false

    // MARK: - Status Text

    private var statusTextView: some View {
        VStack(spacing: 8) {
            Text(statusTitle)
                .font(.title3)
                .fontWeight(.semibold)

            Text(statusSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if case .timeout = state {
                Text(L("Taking too long? Try again."))
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }

    private var statusTitle: String {
        switch state {
        case .connecting: return "Connecting to \(deviceType.displayName)..."
        case .waitingConfirm: return "Please confirm on device"
        case .signing: return "Signing..."
        case .completed: return "Done!"
        case .error(let msg): return "Error: \(msg)"
        case .timeout: return "Connection Timed Out"
        }
    }

    private var statusSubtitle: String {
        switch deviceType {
        case .ledger:
            switch state {
            case .connecting: return "Make sure your Ledger is unlocked and Ethereum app is open"
            case .waitingConfirm: return "Review the transaction on your Ledger device"
            case .signing: return "Processing signature..."
            case .completed: return "Transaction signed successfully"
            case .error: return "Please try again"
            case .timeout: return "Could not connect to your Ledger device"
            }
        case .qrCode:
            switch state {
            case .connecting: return "Scan the QR code with your hardware wallet"
            case .waitingConfirm: return "Scan the signed QR code from your device"
            case .signing: return "Processing QR signature..."
            case .completed: return "Signature received"
            case .error: return "Please try again"
            case .timeout: return "QR signing timed out"
            }
        case .watchOnly:
            switch state {
            case .connecting: return "Requesting co-signer approval..."
            case .waitingConfirm: return "Waiting for approval from co-signer"
            case .signing: return "Processing..."
            case .completed: return "Co-signer approved"
            case .error: return "Please try again"
            case .timeout: return "Co-signer did not respond"
            }
        }
    }

    private var stateColor: Color {
        switch state {
        case .connecting, .signing: return .blue
        case .waitingConfirm: return .orange
        case .completed: return .green
        case .error, .timeout: return .red
        }
    }

    // MARK: - Progress Steps

    private var progressStepsView: some View {
        HStack(spacing: 0) {
            ForEach(SigningStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(step.rawValue <= currentStep.rawValue ? stateColor : Color(.systemGray4))
                            .frame(width: 28, height: 28)

                        if step.rawValue < currentStep.rawValue {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.white)
                        } else {
                            Text("\(step.rawValue + 1)")
                                .font(.caption2)
                                .foregroundColor(step.rawValue <= currentStep.rawValue ? .white : .secondary)
                        }
                    }

                    Text(step.label)
                        .font(.caption2)
                        .foregroundColor(step.rawValue <= currentStep.rawValue ? .primary : .secondary)
                }

                if step != .done {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? stateColor : Color(.systemGray4))
                        .frame(height: 2)
                        .padding(.bottom, 16)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Action Buttons

    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            if case .error = state {
                Button(action: { onRetry?() }) {
                    Text(L("Retry"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else if case .timeout = state {
                Button(action: { onRetry?() }) {
                    Text(L("Try Again"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }

            Button(L("Cancel")) { cancelSigning() }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
        }
    }

    // MARK: - Logic

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeElapsed += 1
            if timeElapsed >= timeoutDuration {
                state = .timeout
                timer?.invalidate()
            }
        }
    }

    private func cancelSigning() {
        timer?.invalidate()
        onCancel?()
        dismiss()
    }
}

// MARK: - QR Signing Sub-Component

struct QRSigningView: View {
    let unsignedTxData: Data
    @State private var isDisplayMode = true
    @State private var scannedSignature: String?

    var onSignatureScanned: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Picker(L("Mode"), selection: $isDisplayMode) {
                Text(L("Show QR")).tag(true)
                Text(L("Scan Signed")).tag(false)
            }
            .pickerStyle(.segmented)

            if isDisplayMode {
                // Display unsigned tx as QR code
                if let qrImage = generateQRCode(from: unsignedTxData) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 280)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
                Text(L("Scan this QR code with your hardware wallet"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Camera scanner placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .frame(height: 280)

                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))

                    Text(L("Point camera at signed QR code"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .offset(y: 60)
                }
            }
        }
    }

    private func generateQRCode(from data: Data) -> UIImage? {
        let hexString = data.map { String(format: "%02x", $0) }.joined()
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(hexString.data(using: .utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        return UIImage(ciImage: scaledImage)
    }
}

// MARK: - WatchOnly Wait Sub-Component

struct WatchOnlyWaitView: View {
    let signerAddress: String
    let unsignedTxHex: String
    @State private var pastedSignature = ""
    @State private var showPasteField = false

    var onSignatureReceived: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .foregroundColor(.blue)
                Text(L("Waiting for approval from"))
                    .font(.subheadline)
            }

            Text(EthereumUtil.truncateAddress(signerAddress))
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

            // Share unsigned tx
            if #available(iOS 16.0, *) {
                ShareLink(item: unsignedTxHex) {
                    Label(L("Share Transaction Data"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
            } else {
                Button(action: {
                    let av = UIActivityViewController(activityItems: [unsignedTxHex], applicationActivities: nil)
                    UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.windows.first?.rootViewController?
                        .present(av, animated: true)
                }) {
                    Label(L("Share Transaction Data"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
            }

            // Manual paste
            Button(action: { showPasteField.toggle() }) {
                Label(L("Paste Signed Transaction"), systemImage: "doc.on.clipboard")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            if showPasteField {
                TextField(L("Paste signed tx hex..."), text: $pastedSignature)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))

                Button(L("Submit")) {
                    if !pastedSignature.isEmpty {
                        onSignatureReceived?(pastedSignature)
                    }
                }
                .disabled(pastedSignature.isEmpty)
            }
        }
    }
}
