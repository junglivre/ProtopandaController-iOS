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
                    LabeledContent("Serviço") {
                        TextField("UUID", text: $serviceText)
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    LabeledContent("Leitura/escrita") {
                        TextField("UUID", text: $readWriteText)
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    LabeledContent("Notificação") {
                        TextField("UUID", text: $notifyText)
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
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
