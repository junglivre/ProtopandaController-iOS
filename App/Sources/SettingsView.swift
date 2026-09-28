import SwiftUI
import Foundation
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
                Section("settings.section_identity") {
                    uuidField("settings.field_service", text: $serviceText)
                    uuidField("settings.field_read_write", text: $readWriteText)
                    uuidField("settings.field_notify", text: $notifyText)
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button("settings.save") { save() }
                    Button("settings.restore_defaults") { populate(with: .default) }
                }

                Section("settings.section_about") {
                    Text(String(format: NSLocalizedString("settings.version", comment: ""), Bundle.main.appVersion))
                    Link("settings.repository_link", destination: URL(string: "https://github.com/junglivre/ProtopandaController-iOS")!)
                }

                Section("settings.section_credits") {
                    Link("settings.credit_goodu", destination: URL(string: "https://github.com/GooDDu")!)
                    Link("settings.credit_mockthebear", destination: URL(string: "https://github.com/mockthebear")!)
                    Link("settings.credit_junglivre", destination: URL(string: "https://github.com/junglivre")!)
                }
            }
            .navigationTitle("settings.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("settings.close") { dismiss() }
                }
            }
            .onAppear { populate(with: viewModel.identity) }
        }
    }

    /// Manual label-above-field row, since `LabeledContent` requires iOS 16+ and this app
    /// targets iOS 15.
    private func uuidField(_ label: LocalizedStringKey, text: Binding<String>) -> some View {
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
            return NSLocalizedString("settings.error_invalid_service_uuid", comment: "")
        case .invalidReadWriteUUID:
            return NSLocalizedString("settings.error_invalid_read_write_uuid", comment: "")
        case .invalidNotifyUUID:
            return NSLocalizedString("settings.error_invalid_notify_uuid", comment: "")
        case .duplicateUUIDs:
            return NSLocalizedString("settings.error_duplicate_uuids", comment: "")
        }
    }
}

private extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }
}
