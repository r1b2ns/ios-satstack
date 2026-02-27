import ActivityKit
import SwiftUI

struct HomeView: View {
    @ObservedObject private var coordinator = MainCoordinator()
    @StateObject  private var tokenManager  = APNsTokenManager.shared

    @State private var txid:              String  = ""
    @State private var statusMessage:     String  = ""
    @State private var isLoading:         Bool    = false
    @State private var statusColor:       Color   = .secondary
    @State private var showCopiedAlert:   Bool    = false
    @State private var currentActivity:   Activity<TransactionActivityAttributes>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // ── Token APNs ───────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.orange)
                        Text("Token APNs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if tokenManager.hasToken {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .symbolEffect(.bounce, value: tokenManager.deviceToken)
                        }
                    }

                    if let token = tokenManager.deviceToken {
                        HStack {
                            Text(token)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                UIPasteboard.general.string = token
                                showCopiedAlert = true
                            } label: {
                                Image(systemName: "doc.on.doc").font(.callout)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        Text("Aguardando registro...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                Divider()

                // ── Transaction ID ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transaction ID")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Cole o TXID aqui…", text: $txid, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.footnote, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .lineLimit(3...6)
                        .submitLabel(.done)
                }

                // ── Botão ────────────────────────────────────────────────────
                Button {
                    Task { await watchTransaction() }
                } label: {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        Text(isLoading ? "Enviando…" : "Monitorar transação")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(txid.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

                // ── Status ───────────────────────────────────────────────────
                if !statusMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: statusColor == .green
                              ? "checkmark.circle.fill"
                              : "xmark.circle.fill")
                        Text(statusMessage).font(.subheadline)
                    }
                    .foregroundStyle(statusColor)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(statusColor.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 10))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Mempool Monitor")
            .alert("Token copiado!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("O token APNs foi copiado para a área de transferência.")
            }
        }
    }

    // MARK: - Watch

    private func watchTransaction() async {
        let cleanTxid = txid.trimmingCharacters(in: .whitespaces)
        guard !cleanTxid.isEmpty else { return }

        isLoading     = true
        statusMessage = ""
        defer { isLoading = false }

        // 1. Inicia a Live Activity e aguarda o push token (com timeout de 3s)
        let activityToken = await beginLiveActivity(txId: cleanTxid)

        // 2. Envia o request via MempoolMonitorAPI
        do {
            try await MempoolMonitorAPI.shared.watchTransaction(
                txId:          cleanTxid,
                deviceToken:   tokenManager.deviceToken ?? "",
                activityToken: activityToken.isEmpty ? nil : activityToken
            )
            statusMessage = "Monitorando transação."
            statusColor   = .green
        } catch {
            statusMessage = (error as? HTTPError)?.localizedDescription
                          ?? error.localizedDescription
            statusColor   = .red
            await currentActivity?.end(dismissalPolicy: .immediate)
        }
    }

    // MARK: - Live Activity

    /// Inicia a Live Activity e retorna o push token hex, ou "" em caso de falha.
    private func beginLiveActivity(txId: String) async -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities desabilitadas pelo usuário.")
            return ""
        }

        do {
            let attributes = TransactionActivityAttributes(txId: txId)
            let state      = TransactionActivityAttributes.ContentState(
                confirmations: 0,
                status:        .pending,
                txId: txid
            )

            let activity = try Activity.request(
                attributes: attributes,
                content:    .init(state: state, staleDate: nil),
                pushType:   .token          // habilita atualizações via APNs
            )

            currentActivity = activity

            // Aguarda o push token; dá 3 segundos antes de prosseguir sem ele.
            let tokenHex = await withTaskGroup(of: String.self) { group in
                group.addTask {
                    for await data in activity.pushTokenUpdates {
                        return data.map { String(format: "%02x", $0) }.joined()
                    }
                    return ""
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(3))
                    return ""
                }
                let result = await group.next() ?? ""
                group.cancelAll()
                return result
            }

            print("🏃 Live Activity iniciada — activityToken: \(tokenHex.prefix(16))…")
            return tokenHex

        } catch {
            print("⚠️ Erro ao iniciar Live Activity: \(error.localizedDescription)")
            return ""
        }
    }
}

#Preview {
    HomeView()
}
