import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - ReceiveAddressSheet

/// Sheet that displays the wallet's receive address as a QR code
/// with a copyable text label underneath.
struct ReceiveAddressSheet: View {

    /// The Bitcoin address to display, or `nil` while still loading.
    let address: String?

    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedFeedback = false

    var body: some View {
        NavigationStack {
            buildContent()
                .navigationTitle("Receive")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Content

    @ViewBuilder
    private func buildContent() -> some View {
        if let address {
            VStack(spacing: 24) {
                Spacer()
                buildQRCode(for: address)
                buildAddressLabel(address)
                Spacer()
            }
            .padding(.horizontal, 20)
        } else {
            buildLoadingState()
        }
    }

    // MARK: - QR Code

    private func buildQRCode(for address: String) -> some View {
        Group {
            if let qrImage = Self.generateQRCode(from: address) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 120))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Address label

    private func buildAddressLabel(_ address: String) -> some View {
        VStack(spacing: 8) {
            Text(address)
                .font(.system(.callout, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Text(showCopiedFeedback ? "Copied!" : "Tap to copy")
                .font(.caption)
                .foregroundStyle(showCopiedFeedback ? .green : .secondary)
                .animation(.easeInOut, value: showCopiedFeedback)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            UIPasteboard.general.string = address
            showCopiedFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showCopiedFeedback = false
            }
        }
    }

    // MARK: - Loading

    private func buildLoadingState() -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Deriving address…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - QR Code generation

private extension ReceiveAddressSheet {

    /// Generates a high-resolution QR code `UIImage` from the given string
    /// using Core Image's built-in `CIQRCodeGenerator`.
    static func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .ascii) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up to avoid blurriness — QR codes are tiny by default.
        let scale: CGFloat = 10
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = ciImage.transformed(by: transform)

        return UIImage(ciImage: scaledImage)
    }
}
