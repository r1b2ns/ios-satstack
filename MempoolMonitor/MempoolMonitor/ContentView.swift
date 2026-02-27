import SwiftUI

struct ContentView: View {
    @StateObject private var tokenManager = APNsTokenManager.shared
    
    @State private var txid: String = "36cee26102cd9676b9c812c7e6a4cdbf3d4b66f249be3df6765a0c3f9cc8bba7"
    @State private var statusMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var statusColor: Color = .secondary
    @State private var showCopiedAlert: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Seção do Token APNs
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
                                Image(systemName: "doc.on.doc")
                                    .font(.callout)
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

                Button {
                    Task { await watchTransaction() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isLoading ? "Enviando…" : "Monitorar transação")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(txid.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

                if !statusMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: statusColor == .green ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(statusMessage)
                            .font(.subheadline)
                    }
                    .foregroundStyle(statusColor)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(statusColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Mempool Monitor")
            .alert("Token copiado!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("O token APNs foi copiado para a área de transferência.")
            }
        }
    }

    private func watchTransaction() async {
        let cleanTxid = txid.trimmingCharacters(in: .whitespaces)
        guard !cleanTxid.isEmpty else { return }

        isLoading = true
        statusMessage = ""

        defer { isLoading = false }

        guard let url = URL(string: "http://localhost:3000/tx/\(cleanTxid)/watch") else {
            statusMessage = "TXID inválido."
            statusColor = .red
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10
            
            // Enviar o token APNs no corpo da requisição
            if let token = tokenManager.deviceToken {
                let payload: [String: String] = ["device_token": token]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            }

            let (_, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    statusMessage = "Transação enviada para monitoramento. (\(http.statusCode))"
                    statusColor = .green
                } else {
                    statusMessage = "Erro do servidor: HTTP \(http.statusCode)."
                    statusColor = .red
                }
            }
        } catch {
            statusMessage = "Falha na requisição: \(error.localizedDescription)"
            statusColor = .red
        }
    }
}

#Preview {
    ContentView()
}
