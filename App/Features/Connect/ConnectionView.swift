import NetworkExtension
import SwiftUI
import SwiftShieldCore

struct ConnectionView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var tunnel: TunnelController
    @State private var showsImport = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                statusHeader
                powerButton
                profilePicker
                engineNotice
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("SwiftShield")
        .sheet(isPresented: $showsImport) {
            ImportProfileView()
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 8) {
            Text(tunnel.statusTitle)
                .font(.title2.weight(.semibold))
            Text(statusSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var powerButton: some View {
        Button {
            Task { await appModel.toggleConnection() }
        } label: {
            ZStack {
                Circle()
                    .fill(buttonColor.opacity(0.13))
                    .frame(width: 184, height: 184)
                Circle()
                    .fill(buttonColor)
                    .frame(width: 144, height: 144)
                    .shadow(color: buttonColor.opacity(0.3), radius: 18, y: 10)
                Image(systemName: "power")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 184, height: 184)
        }
        .buttonStyle(.plain)
        .disabled(appModel.selectedProfile == nil || tunnel.isBusy)
        .opacity(appModel.selectedProfile == nil ? 0.45 : 1)
        .accessibilityLabel(tunnel.isActive ? "Отключить VPN" : "Подключить VPN")
    }

    private var profilePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ПРОФИЛЬ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if appModel.profiles.isEmpty {
                Button {
                    showsImport = true
                } label: {
                    Label("Добавить первый профиль", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
            } else {
                Menu {
                    ForEach(appModel.profiles) { profile in
                        Button {
                            appModel.select(profile)
                        } label: {
                            Label(profile.name, systemImage: profile.id == appModel.selectedProfileID ? "checkmark" : "server.rack")
                        }
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "server.rack")
                            .foregroundStyle(Color.shieldBlue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(appModel.selectedProfile?.name ?? "Выберите профиль")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let profile = appModel.selectedProfile {
                                Text("\(profile.kind.title) · \(profile.server):\(profile.port)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var engineNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .foregroundStyle(Color.shieldOrange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Сетевое ядро не подключено")
                    .font(.subheadline.weight(.semibold))
                Text("Импорт и системная конфигурация готовы. Для передачи трафика требуется добавить Libbox.xcframework.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private var buttonColor: Color {
        switch tunnel.status {
        case .connected: return .shieldGreen
        case .connecting, .reasserting: return .shieldOrange
        default: return .shieldBlue
        }
    }

    private var statusSubtitle: String {
        if appModel.profiles.isEmpty { return "Добавьте ключ или подписку, чтобы начать" }
        if tunnel.status == .connected { return appModel.selectedProfile?.name ?? "VPN активен" }
        return "Трафик сейчас идёт без защиты SwiftShield"
    }
}
