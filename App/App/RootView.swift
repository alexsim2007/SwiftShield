import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView {
            NavigationStack {
                ConnectionView(tunnel: appModel.tunnelController)
            }
            .tabItem { Label("Подключение", systemImage: "shield.lefthalf.filled") }

            NavigationStack {
                ProfilesView()
            }
            .tabItem { Label("Профили", systemImage: "server.rack") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .tint(.primary)
        .onOpenURL { url in
            Task { await appModel.handle(url) }
        }
        .alert(item: $appModel.presentedError) { error in
            Alert(
                title: Text("SwiftShield"),
                message: Text(error.message),
                dismissButton: .default(Text("Понятно"))
            )
        }
    }
}
