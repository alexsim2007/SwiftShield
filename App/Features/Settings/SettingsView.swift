import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("Приватность") {
                Label("Профили хранятся на устройстве", systemImage: "iphone.and.arrow.forward")
                Label("Подписки загружаются напрямую", systemImage: "arrow.down.shield")
            }

            Section("Поддержка") {
                LabeledContent("Форматы", value: "VLESS, Trojan, SS")
                LabeledContent("Минимальная iOS", value: "17.0")
                LabeledContent("Сетевое ядро", value: "Не подключено")
            }

            Section("О приложении") {
                LabeledContent("Версия", value: appVersion)
                LabeledContent("Проект", value: "SwiftShield VPN")
            }
        }
        .navigationTitle("Настройки")
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}

