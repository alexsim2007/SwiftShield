import SwiftUI

struct ImportProfileView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case key = "Ключ"
        case subscription = "Подписка"
        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel
    @State private var mode: Mode = .key
    @State private var value = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Тип импорта", selection: $mode) {
                        ForEach(Mode.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if mode == .key {
                        TextEditor(text: $value)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(minHeight: 170)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        TextField("https://example.com/subscription", text: $value)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text(mode == .key ? "Ключ или содержимое" : "HTTPS-ссылка")
                } footer: {
                    Text(mode == .key
                         ? "Поддерживаются VLESS, Trojan, Shadowsocks, Base64 и sing-box JSON."
                         : "SwiftShield загрузит подписку напрямую, без сторонних серверов.")
                }
            }
            .navigationTitle("Новый профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Импорт") {
                        Task {
                            let success = mode == .key
                                ? await appModel.importText(value)
                                : await appModel.importSubscription(value)
                            if success { dismiss() }
                        }
                    }
                    .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.isImporting)
                }
            }
            .overlay {
                if appModel.isImporting {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
