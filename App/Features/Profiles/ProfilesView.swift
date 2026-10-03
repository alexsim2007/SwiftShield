import SwiftUI
import SwiftShieldCore

struct ProfilesView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showsImport = false

    var body: some View {
        Group {
            if appModel.profiles.isEmpty {
                ContentUnavailableView {
                    Label("Нет профилей", systemImage: "server.rack")
                } description: {
                    Text("Добавьте ключ VLESS, Trojan, Shadowsocks или ссылку на подписку.")
                } actions: {
                    Button("Добавить профиль") { showsImport = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                }
            } else {
                List {
                    ForEach(appModel.profiles) { profile in
                        ProfileRow(profile: profile, isSelected: profile.id == appModel.selectedProfileID)
                            .contentShape(Rectangle())
                            .onTapGesture { appModel.select(profile) }
                    }
                    .onDelete { offsets in
                        Task { await appModel.delete(at: offsets) }
                    }
                }
            }
        }
        .navigationTitle("Профили")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsImport = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Добавить профиль")
            }
        }
        .sheet(isPresented: $showsImport) {
            ImportProfileView()
        }
    }
}

private struct ProfileRow: View {
    let profile: TunnelProfile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: protocolIcon)
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.body.weight(.medium))
                Text("\(profile.kind.title) · \(profile.server):\(profile.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 5)
    }

    private var protocolIcon: String {
        switch profile.kind {
        case .vless: return "bolt.shield.fill"
        case .trojan: return "lock.shield.fill"
        case .shadowsocks: return "network"
        }
    }
}
