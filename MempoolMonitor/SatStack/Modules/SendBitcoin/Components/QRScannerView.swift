import AVFoundation
import SwiftUI

// MARK: - QRScannerView

/// A camera-based QR code scanner presented as a full-screen cover.
///
/// Uses AVFoundation's `AVCaptureSession` to detect QR codes in real time.
/// When a code is found, `onCodeScanned` is called with the payload string.
struct QRScannerView: View {

    /// Called when a QR code is successfully scanned.
    let onCodeScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            QRScannerRepresentable(onCodeScanned: { code in
                onCodeScanned(code)
                dismiss()
            })
            .ignoresSafeArea()

            buildCloseButton()
        }
    }

    // MARK: - Close button

    private func buildCloseButton() -> some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .padding()
        }
    }
}

// MARK: - UIViewControllerRepresentable

/// Bridges AVFoundation's camera session into SwiftUI for QR code scanning.
private struct QRScannerRepresentable: UIViewControllerRepresentable {

    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

// MARK: - ScannerViewController

/// UIKit view controller that runs an `AVCaptureSession` and scans for QR codes.
private class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var onCodeScanned: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    // MARK: - Camera setup

    private func setupCamera() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            Log.print.warning("No video capture device available for QR scanning")
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            Log.print.error("Failed to create video input: \(error.localizedDescription)")
            return
        }

        guard captureSession.canAddInput(videoInput) else {
            Log.print.error("Cannot add video input to capture session")
            return
        }
        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            Log.print.error("Cannot add metadata output to capture session")
            return
        }
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue
        else { return }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onCodeScanned?(stringValue)
    }
}
