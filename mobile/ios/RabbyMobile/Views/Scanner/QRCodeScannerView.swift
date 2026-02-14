import SwiftUI
import AVFoundation

// MARK: - Usage
// .sheet(isPresented: $showScanner) {
//     QRCodeScannerView { result in handleResult(result) }
// }

// MARK: - QR Scan Result

/// Categorized result from scanning a QR code
enum QRScanResult {
    case walletConnectURI(String)    // wc: prefix
    case ethereumAddress(String)      // 0x prefix, 42 characters
    case url(String)                  // http/https prefix
    case text(String)                 // anything else

    /// Parse a raw scanned string into a categorized result
    static func parse(_ raw: String) -> QRScanResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.lowercased().hasPrefix("wc:") {
            return .walletConnectURI(trimmed)
        }

        if trimmed.hasPrefix("0x"), trimmed.count == 42 {
            let hexPart = trimmed.dropFirst(2)
            let isValidHex = hexPart.allSatisfy { $0.isHexDigit }
            if isValidHex {
                return .ethereumAddress(trimmed)
            }
        }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return .url(trimmed)
        }

        return .text(trimmed)
    }
}

// MARK: - QRCodeScannerView

/// Full-screen QR code scanner with camera preview, scan frame overlay,
/// and flashlight toggle. Presented modally via `.sheet`.
struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss

    /// Callback invoked once when a QR code is successfully scanned.
    let onScanResult: (QRScanResult) -> Void

    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var isTorchOn = false
    @State private var hasScanned = false

    var body: some View {
        NavigationView {
            ZStack {
                switch cameraPermission {
                case .authorized:
                    cameraPreviewLayer
                    scanFrameOverlay
                    torchButton

                case .denied, .restricted:
                    permissionDeniedView

                case .notDetermined:
                    Color.black.ignoresSafeArea()
                        .overlay(ProgressView().tint(.white))

                @unknown default:
                    Color.black.ignoresSafeArea()
                }
            }
            .navigationTitle(L("Scan QR Code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                let navAppearance = UINavigationBarAppearance()
                navAppearance.configureWithTransparentBackground()
                UINavigationBar.appearance().standardAppearance = navAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
            }
        }
        .onAppear { checkCameraPermission() }
        .onChange(of: isTorchOn) { newValue in
            setTorch(on: newValue)
        }
    }

    // MARK: - Camera Preview

    private var cameraPreviewLayer: some View {
        QRScannerRepresentable(
            onCodeScanned: { code in
                guard !hasScanned else { return }
                hasScanned = true

                // Haptic feedback on success
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                let result = QRScanResult.parse(code)
                onScanResult(result)
                dismiss()
            }
        )
        .ignoresSafeArea()
    }

    // MARK: - Scan Frame Overlay

    private var scanFrameOverlay: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.65
            let rect = CGRect(
                x: (geo.size.width - side) / 2,
                y: (geo.size.height - side) / 2,
                width: side,
                height: side
            )

            ZStack {
                // Dimmed background outside scan area
                ScanFrameDimOverlay(scanRect: rect, color: Color.black.opacity(0.5))
                    .ignoresSafeArea()

                // Corner highlights
                ScanCorners(rect: rect, cornerLength: 24, lineWidth: 4)
                    .stroke(Color.blue, lineWidth: 4)

                // Instruction text below frame
                VStack {
                    Spacer()
                        .frame(height: rect.maxY + 32)
                    Text(L("Align QR code within the frame"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
            }
        }
    }

    // MARK: - Torch Button

    private var torchButton: some View {
        VStack {
            Spacer()
            Button(action: { isTorchOn.toggle() }) {
                VStack(spacing: 6) {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(isTorchOn ? "On" : "Off")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(isTorchOn ? Color.blue.opacity(0.6) : Color.white.opacity(0.15))
                )
            }
            .padding(.bottom, 60)
        }
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(L("Camera Access Required"))
                .font(.title2)
                .fontWeight(.bold)

            Text(L("Rabby needs camera access to scan QR codes. Please enable it in Settings."))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: openAppSettings) {
                Text(L("Go to Settings"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermission = status

        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        }
    }

    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error.localizedDescription)")
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - QRScannerRepresentable (UIViewControllerRepresentable)

/// Bridges AVCaptureSession-based QR scanning into SwiftUI.
struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

// MARK: - QRScannerViewController

/// UIKit view controller that manages AVCaptureSession for QR code scanning.
final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isSessionRunning = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    // MARK: Setup

    private func setupCaptureSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            print("QRScanner: No back camera available")
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("QRScanner: Cannot create video input - \(error.localizedDescription)")
            return
        }

        guard captureSession.canAddInput(videoInput) else {
            print("QRScanner: Cannot add video input to session")
            return
        }
        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            print("QRScanner: Cannot add metadata output to session")
            return
        }
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    // MARK: Session Lifecycle

    private func startSession() {
        guard !isSessionRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            self?.isSessionRunning = true
        }
    }

    private func stopSession() {
        guard isSessionRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            self?.isSessionRunning = false
        }
    }

    // MARK: AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let stringValue = metadataObject.stringValue else { return }

        // Stop the session immediately to prevent duplicate callbacks
        stopSession()
        onCodeScanned?(stringValue)
    }
}

// MARK: - Overlay Shapes

/// View that fills everything except the scan rectangle (creates a "window" effect)
/// using even-odd fill rule so the scan rect is transparent.
struct ScanFrameDimOverlay: View {
    let scanRect: CGRect
    let color: Color

    var body: some View {
        Canvas { context, size in
            var outer = Path()
            outer.addRect(CGRect(origin: .zero, size: size))
            outer.addRoundedRect(
                in: scanRect,
                cornerSize: CGSize(width: 4, height: 4)
            )
            context.fill(outer, with: .color(color), style: FillStyle(eoFill: true))
        }
    }
}

/// Shape that draws corner brackets around the scan rectangle.
struct ScanCorners: Shape {
    let rect: CGRect
    let cornerLength: CGFloat
    let lineWidth: CGFloat

    func path(in bounds: CGRect) -> Path {
        var path = Path()

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))

        return path
    }
}

// MARK: - Preview

struct QRCodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeScannerView { result in
            print("Scanned: \(result)")
        }
    }
}
