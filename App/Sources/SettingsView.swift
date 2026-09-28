import SwiftUI
import ProtopandaControllerCore

struct SettingsView: View {
    @ObservedObject var viewModel: ControllerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var serviceText: String = ""
    @State private var readWriteText: String = ""
    @State private var notifyText: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Identidade BLE") {
                    uuidField("Serviço", text: $serviceText)
                    uuidField("Leitura/escrita", text: $readWriteText)
                    uuidField("Notificação", text: $notifyText)
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button("Salvar") { save() }
                    Button("Restaurar padrões") { populate(with: .default) }
                }

                Section("Sobre") {
                    Text("Versão \(Bundle.main.appVersion)")
                    Link("Repositório no GitHub", destination: URL(string: "https://github.com/junglivre/ProtopandaController-iOS")!)
                }

                Section("Créditos") {
                    Link("GooDDu — primeira versão do app Android", destination: URL(string: "https://github.com/GooDDu")!)
                    Link("mockthebear — criador do Protopanda", destination: URL(string: "https://github.com/mockthebear")!)
                    Link("junglivre — porte iOS e app Android", destination: URL(string: "https://github.com/junglivre")!)
                }
            }
            .navigationTitle("Configurações")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onAppear { populate(with: viewModel.identity) }
        }
    }

    /// Manual label-above-field row, since `LabeledContent` requires iOS 16+ and this app
    /// targets iOS 15.
    private func uuidField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("UUID", text: text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    private func populate(with identity: BLEIdentity) {
        serviceText = identity.serviceUUID.uuidString
        readWriteText = identity.readWriteUUID.uuidString
        notifyText = identity.notifyUUID.uuidString
        errorMessage = nil
    }

    private func save() {
        if let error = viewModel.saveIdentity(
            serviceText: serviceText,
            readWriteText: readWriteText,
            notifyText: notifyText
        ) {
            errorMessage = message(for: error)
            return
        }
        dismiss()
    }

    private func message(for error: ControllerViewModel.IdentityValidationError) -> String {
        switch error {
        case .invalidServiceUUID:
            return "UUID de serviço inválido."
        case .invalidReadWriteUUID:
            return "UUID de leitura/escrita inválido."
        case .invalidNotifyUUID:
            return "UUID de notificação inválido."
        case .duplicateUUIDs:
            return "Os três UUIDs precisam ser diferentes."
        }
    }
}

private extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }
}
