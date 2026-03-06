import BitcoinUI
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
        QRCodeView(qrCodeType: .bitcoin(address))
            .frame(width: 250, height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Address label

    private func buildAddressLabel(_ address: String) -> some View {
        Button {
            UIPasteboard.general.string = address
            showCopiedFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showCopiedFeedback = false
            }
        } label: {
            VStack(spacing: 8) {
                Text(address)
                    .font(.system(.callout, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                
                Text(showCopiedFeedback ? "Copied!" : "Tap to copy")
                    .font(.caption)
                    .animation(.easeInOut, value: showCopiedFeedback)
            }
        }
        .foregroundStyle(showCopiedFeedback ? .green : .secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
