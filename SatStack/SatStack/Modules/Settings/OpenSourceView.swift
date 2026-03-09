import SwiftUI

// MARK: - Model

private struct OpenSourcePackage: Identifiable {
    let id = UUID()
    let name: String
    let githubURL: URL
    let description: String
    let license: String
}

// MARK: - View

struct OpenSourceView: View {

    @Environment(\.appTheme) private var theme

    private let packages: [OpenSourcePackage] = [
        .init(
            name: "bdk-swift",
            githubURL: URL(string: "https://github.com/bitcoindevkit/bdk-swift")!,
            description: "Swift language bindings for the Bitcoin Dev Kit",
            license: "MIT & Apache 2.0"
        ),
        .init(
            name: "BitcoinUI",
            githubURL: URL(string: "https://github.com/reez/BitcoinUI")!,
            description: "Bitcoin UI components for SwiftUI",
            license: "MIT"
        ),
        .init(
            name: "netfox",
            githubURL: URL(string: "https://github.com/rubensmachion/netfox")!,
            description: "A lightweight network debugging library for iOS / macOS",
            license: "MIT"
        )
    ]

    var body: some View {
        List {
            Section {
                ForEach(packages) { package in
                    buildPackageRow(package)
                }
            } header: {
                Text("SatStack is built on top of the following open source projects. Tap any item to view its repository on GitHub.")
                    .textCase(nil)
                    .font(.footnote)
                    .foregroundStyle(theme.colors.contentSecondary)
                    .padding(.bottom, 4)
            }
        }
        .navigationTitle("Open Source Software")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPackageRow(_ package: OpenSourcePackage) -> some View {
        Link(destination: package.githubURL) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.title3)
                    .foregroundStyle(theme.colors.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(package.name)
                        .font(theme.typography.subheadline)
                        .fontWeight(.medium)
                    Text(package.description)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.contentSecondary)
                    Text("License: \(package.license)")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.contentSecondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(theme.colors.contentSecondary)
            }
        }
        .foregroundStyle(.primary)
    }
}
