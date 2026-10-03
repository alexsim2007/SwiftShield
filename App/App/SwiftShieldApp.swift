import SwiftUI

@main
struct SwiftShieldApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .task { await appModel.start() }
        }
    }
}

