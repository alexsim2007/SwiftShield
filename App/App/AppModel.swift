import Foundation
import SwiftShieldCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var profiles: [TunnelProfile] = []
    @Published var selectedProfileID: UUID?
    @Published var presentedError: AppError?
    @Published var isImporting = false
    @Published var tunnelSettings: TunnelSettings {
        didSet { persistTunnelSettings() }
    }

    let tunnelController = TunnelController()

    private let parser = SubscriptionParser()
    private let client = SubscriptionClient()
    private var store: SharedProfileStore?

    init() {
        tunnelSettings = Self.restoreTunnelSettings()
    }

    var selectedProfile: TunnelProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    func start() async {
        do {
            let store = try SharedProfileStore()
            self.store = store
            profiles = try await store.load()
            selectedProfileID = restoredSelection() ?? profiles.first?.id
            await tunnelController.prepare()
        } catch {
            present(error)
        }
    }

    func select(_ profile: TunnelProfile) {
        selectedProfileID = profile.id
        UserDefaults.standard.set(profile.id.uuidString, forKey: "selectedProfileID")
    }

    func importText(_ text: String) async -> Bool {
        await performImport {
            try parser.parse(text)
        }
    }

    func importSubscription(_ rawURL: String) async -> Bool {
        await performImport {
            let value = try await client.fetch(from: rawURL)
            return try parser.parse(value)
        }
    }

    func delete(at offsets: IndexSet) async {
        for index in offsets.sorted(by: >) {
            profiles.remove(at: index)
        }
        if !profiles.contains(where: { $0.id == selectedProfileID }) {
            selectedProfileID = profiles.first?.id
        }
        await persist()
    }

    func toggleConnection() async {
        do {
            if tunnelController.isActive {
                try await tunnelController.disconnect()
            } else {
                guard let profile = selectedProfile else {
                    throw AppError(message: "Сначала добавьте и выберите профиль.")
                }
                try await tunnelController.connect(profile: profile, settings: tunnelSettings)
            }
        } catch {
            present(error)
        }
    }

    private func performImport(_ operation: () async throws -> [TunnelProfile]) async -> Bool {
        isImporting = true
        defer { isImporting = false }
        do {
            let imported = try await operation()
            let existing = Set(profiles.map(\.originalURI))
            let newProfiles = imported.filter { !existing.contains($0.originalURI) }
            profiles.append(contentsOf: newProfiles)
            if selectedProfileID == nil { selectedProfileID = profiles.first?.id }
            await persist()
            return true
        } catch {
            present(error)
            return false
        }
    }

    private func persist() async {
        do {
            try await store?.save(profiles)
        } catch {
            present(error)
        }
    }

    private func restoredSelection() -> UUID? {
        guard let rawValue = UserDefaults.standard.string(forKey: "selectedProfileID") else { return nil }
        return UUID(uuidString: rawValue)
    }

    func handle(_ url: URL) async {
        guard url.scheme == "swiftshield", url.host == "disconnect" else { return }
        do {
            try await tunnelController.disconnect()
        } catch {
            present(error)
        }
    }

    func resetTunnelSettings() {
        tunnelSettings = TunnelSettings()
    }

    private func persistTunnelSettings() {
        guard let data = try? JSONEncoder().encode(tunnelSettings) else { return }
        UserDefaults.standard.set(data, forKey: "tunnelSettings")
    }

    private static func restoreTunnelSettings() -> TunnelSettings {
        guard let data = UserDefaults.standard.data(forKey: "tunnelSettings"),
              let settings = try? JSONDecoder().decode(TunnelSettings.self, from: data) else {
            return TunnelSettings()
        }
        return settings
    }

    private func present(_ error: Error) {
        presentedError = AppError(message: error.localizedDescription)
    }
}

struct AppError: Identifiable, LocalizedError {
    let id = UUID()
    let message: String

    var errorDescription: String? { message }
}
