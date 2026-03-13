import PDFKit
import SwiftUI

// MARK: - View

/// Displays the Bitcoin whitepaper PDF.
///
/// Selects the localized version based on the device's preferred language:
/// - Portuguese (Brazil) → `bitcoin_pt_br.pdf`
/// - All other locales   → `bitcoin_en.pdf`
struct BitcoinWhitepaperView: View {

    @State private var isPresentingShareSheet = false

    var body: some View {
        PDFKitView(url: pdfURL)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Bitcoin Whitepaper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: pdfURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
    }

    // MARK: - Private

    /// Resolves the PDF file URL based on the current locale.
    private var pdfURL: URL {
        let fileName = Locale.current.language.languageCode?.identifier == "pt"
            ? "bitcoin_pt_br"
            : "bitcoin_en"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "pdf") else {
            return Bundle.main.url(forResource: "bitcoin_en", withExtension: "pdf")!
        }
        return url
    }
}

// MARK: - PDFKit wrapper

/// A `UIViewRepresentable` wrapper around PDFKit's `PDFView`.
private struct PDFKitView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
