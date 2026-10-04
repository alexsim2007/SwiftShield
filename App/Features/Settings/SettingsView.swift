import SwiftUI
import SwiftShieldCore

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        List {
            multiplexSection
            transportSection
            networkSection
            diagnosticsSection
            aboutSection
        }
        .tint(.primary)
        .navigationTitle("Настройки")
    }

    private var multiplexSection: some View {
        Section("Мультиплексирование") {
            Toggle("MUX", isOn: $appModel.tunnelSettings.multiplexEnabled)

            Picker("Протокол", selection: $appModel.tunnelSettings.multiplexProtocol) {
                ForEach(TunnelSettings.MultiplexProtocol.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .disabled(!appModel.tunnelSettings.multiplexEnabled)

            Picker("Ограничение", selection: $appModel.tunnelSettings.multiplexLimit) {
                Text("Соединения").tag(TunnelSettings.MultiplexLimit.connections)
                Text("Потоки").tag(TunnelSettings.MultiplexLimit.streams)
            }
            .pickerStyle(.segmented)
            .disabled(!appModel.tunnelSettings.multiplexEnabled)

            if appModel.tunnelSettings.multiplexLimit == .connections {
                Stepper(
                    "Соединений: \(appModel.tunnelSettings.multiplexMaxConnections)",
                    value: $appModel.tunnelSettings.multiplexMaxConnections,
                    in: 1...32
                )
                .disabled(!appModel.tunnelSettings.multiplexEnabled)
                Stepper(
                    "Минимум потоков: \(appModel.tunnelSettings.multiplexMinStreams)",
                    value: $appModel.tunnelSettings.multiplexMinStreams,
                    in: 1...64
                )
                .disabled(!appModel.tunnelSettings.multiplexEnabled)
            } else {
                Stepper(
                    "Потоков: \(appModel.tunnelSettings.multiplexMaxStreams)",
                    value: $appModel.tunnelSettings.multiplexMaxStreams,
                    in: 1...256
                )
                .disabled(!appModel.tunnelSettings.multiplexEnabled)
            }

            Toggle("Padding", isOn: $appModel.tunnelSettings.multiplexPadding)
                .disabled(!appModel.tunnelSettings.multiplexEnabled)
        }
    }

    private var transportSection: some View {
        Section("Транспорт") {
            Toggle(
                "Фрагментация TLS-записей",
                isOn: $appModel.tunnelSettings.tlsRecordFragmentationEnabled
            )
            Toggle(
                "Фрагментация TLS-пакетов",
                isOn: $appModel.tunnelSettings.tlsFragmentationEnabled
            )
            Stepper(
                "Задержка: \(appModel.tunnelSettings.tlsFragmentFallbackDelayMilliseconds) мс",
                value: $appModel.tunnelSettings.tlsFragmentFallbackDelayMilliseconds,
                in: 20...5_000,
                step: 20
            )
            .disabled(!appModel.tunnelSettings.tlsFragmentationEnabled)

            Toggle("TCP Fast Open", isOn: $appModel.tunnelSettings.tcpFastOpenEnabled)
            Toggle("Фрагментация UDP", isOn: $appModel.tunnelSettings.udpFragmentationEnabled)

            Picker("Пакеты VLESS", selection: $appModel.tunnelSettings.packetEncoding) {
                Text("Без упаковки").tag(TunnelSettings.PacketEncoding.none)
                Text("XUDP").tag(TunnelSettings.PacketEncoding.xudp)
                Text("Packet Address").tag(TunnelSettings.PacketEncoding.packetAddress)
            }
        }
    }

    private var networkSection: some View {
        Section("Сеть и DNS") {
            Picker("DNS", selection: $appModel.tunnelSettings.dnsProvider) {
                Text("Cloudflare").tag(TunnelSettings.DNSProvider.cloudflare)
                Text("Google").tag(TunnelSettings.DNSProvider.google)
                Text("Quad9").tag(TunnelSettings.DNSProvider.quad9)
            }

            Picker("IP-стратегия", selection: $appModel.tunnelSettings.ipStrategy) {
                Text("Автоматически").tag(TunnelSettings.IPStrategy.automatic)
                Text("Предпочитать IPv4").tag(TunnelSettings.IPStrategy.preferIPv4)
                Text("Предпочитать IPv6").tag(TunnelSettings.IPStrategy.preferIPv6)
                Text("Только IPv4").tag(TunnelSettings.IPStrategy.ipv4Only)
                Text("Только IPv6").tag(TunnelSettings.IPStrategy.ipv6Only)
            }

            Picker("Выбор сети", selection: $appModel.tunnelSettings.networkStrategy) {
                Text("Системный").tag(TunnelSettings.NetworkStrategy.systemDefault)
                Text("Гибридный").tag(TunnelSettings.NetworkStrategy.hybrid)
                Text("С резервом").tag(TunnelSettings.NetworkStrategy.fallback)
            }
            .disabled(appModel.tunnelSettings.tcpFastOpenEnabled)

            Stepper(
                "MTU: \(appModel.tunnelSettings.tunMTU)",
                value: $appModel.tunnelSettings.tunMTU,
                in: 1280...9000,
                step: 40
            )
            Toggle("Кэш DNS", isOn: $appModel.tunnelSettings.dnsCacheEnabled)
            Toggle("Определение протоколов", isOn: $appModel.tunnelSettings.sniffingEnabled)
            Toggle("Локальная сеть напрямую", isOn: $appModel.tunnelSettings.bypassPrivateNetworks)
        }
    }

    private var diagnosticsSection: some View {
        Section("Диагностика") {
            Picker("Уровень журнала", selection: $appModel.tunnelSettings.logLevel) {
                Text("Только ошибки").tag(TunnelSettings.LogLevel.error)
                Text("Предупреждения").tag(TunnelSettings.LogLevel.warn)
                Text("Информация").tag(TunnelSettings.LogLevel.info)
                Text("Отладка").tag(TunnelSettings.LogLevel.debug)
            }

            Button("Вернуть стандартные настройки") {
                appModel.resetTunnelSettings()
            }
            .foregroundStyle(.primary)
        }
    }

    private var aboutSection: some View {
        Section("О приложении") {
            LabeledContent("Версия", value: appVersion)
            LabeledContent("Сетевое ядро", value: "sing-box")
            LabeledContent("Форматы", value: "VLESS, Trojan, SS")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }
}
