import CoreImage.CIFilterBuiltins
import SwiftUI

struct BuyMeACoffeeView: View {

    @Environment(\.appTheme) private var theme
    @State private var showCopiedFeedback = false

    // Replace with your actual Bitcoin address
    private let bitcoinAddress = "bc1q8dq4xq94sxtp79yfr02qpqtev4w6dgpnh8f3w8"

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                buildHeaderSection()
                buildQRCodeSection()
                buildAddressSection()
            }
            .padding()
            .padding(.top, 16)
        }
        .navigationTitle("Buy Me a Coffee")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private func buildHeaderSection() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 56))
                .foregroundStyle(theme.colors.accent)

            Text("Support the Project")
                .font(theme.typography.title)
                .fontWeight(.bold)

            Text("If you find this app useful, consider sending a small tip in Bitcoin. Every satoshi helps keep the project alive!")
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colors.contentSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func buildQRCodeSection() -> some View {
        Group {
            if let qrImage = generateQRCode(from: "bitcoin:\(bitcoinAddress)") {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func buildAddressSection() -> some View {
        VStack(spacing: 12) {
            Text("Bitcoin Address")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.contentSecondary)
                .textCase(.uppercase)

            Text(bitcoinAddress)
                .font(.system(.caption, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = bitcoinAddress
                    showCopiedFeedback = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showCopiedFeedback = false
                    }
                } label: {
                    Label(
                        showCopiedFeedback ? "Copied!" : "Copy Address",
                        systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc"
                    )
                    .font(theme.typography.subheadline)
                    .fontWeight(.medium)
                    .animation(.easeInOut, value: showCopiedFeedback)
                }
                .buttonStyle(.bordered)
                .tint(theme.colors.accent)

                ShareLink(item: bitcoinAddress) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(theme.typography.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(theme.colors.accent)
            }
        }
    }

    // MARK: - QR Code generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
