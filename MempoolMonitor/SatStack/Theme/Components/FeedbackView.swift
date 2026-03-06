import SwiftUI

// MARK: - FeedbackView

/// A reusable full-screen feedback component for presenting results to the user.
///
/// Designed to be shown as a sheet, fullScreenCover, or as a navigation destination.
/// All content is injected — nothing is hard-coded.
///
/// **Layout:**
/// ```
/// ┌──────────────────────────┐
/// │                          │
/// │       [Image]            │
/// │                          │
/// │    Title (bold)          │
/// │  Subtitle (optional)     │
/// │                          │
/// │   ┌──────────────────┐   │
/// │   │  [Button Title]  │   │
/// │   └──────────────────┘   │
/// └──────────────────────────┘
/// ```
///
/// Usage:
/// ```swift
/// FeedbackView(
///     image: Image(systemName: "checkmark.circle.fill"),
///     title: "Transaction Sent",
///     subtitle: "Your transaction has been broadcast to the network.",
///     buttonTitle: "OK",
///     action: { dismiss() }
/// )
/// ```
struct FeedbackView: View {

    /// The illustrative image displayed at the center of the screen.
    let image: Image

    /// The primary title displayed in bold below the image.
    let title: String

    /// An optional subtitle displayed in regular weight below the title.
    var subtitle: String? = nil

    /// The label for the bottom action button.
    let buttonTitle: String

    /// The action executed when the user taps the button.
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            buildImage()
            buildTitle()
            buildSubtitle()
            Spacer()
            buildButton()
        }
    }

    // MARK: - Image

    private func buildImage() -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
    }

    // MARK: - Title

    private func buildTitle() -> some View {
        Text(title)
            .font(.title2)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .padding(.top, 24)
            .padding(.horizontal, 20)
    }

    // MARK: - Subtitle

    @ViewBuilder
    private func buildSubtitle() -> some View {
        if let subtitle {
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Button

    private func buildButton() -> some View {
        Button(action: action) {
            Text(buttonTitle)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}
