import Combine
import Foundation
import NetworkExtension
import SwiftShieldCore

@MainActor
final class TunnelController: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var isBusy = false

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    var isActive: Bool {
        [.connected, .connecting, .reasserting].contains(status)
    }

    var statusTitle: String {
        switch status {
        case .connected: return "Защищено"
        case .connecting: return "Подключение"
        case .disconnecting: return "Отключение"
        case .reasserting: return "Переподключение"
        case .disconnected: return "Не подключено"
        case .invalid: return "Требуется настройка"
        @unknown default: return "Неизвестно"
        }
    }

    init() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
    }

    deinit {
        if let statusObserver { NotificationCenter.default.removeObserver(statusObserver) }
    }

    func prepare() async {
        do {
            manager = try await loadManager()
            refreshStatus()
        } catch {
            status = .invalid
        }
    }

    func connect(profile: TunnelProfile) async throws {
        #if targetEnvironment(simulator)
        throw TunnelControllerError.simulatorUnsupported
        #else
        isBusy = true
        defer { isBusy = false }

        let manager = try await loadManager()
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = AppConstants.tunnelBundleIdentifier
        tunnelProtocol.serverAddress = profile.server
        tunnelProtocol.includeAllNetworks = true
        tunnelProtocol.excludeLocalNetworks = false
        let payload = try JSONEncoder().encode(profile).base64EncodedString()
        tunnelProtocol.providerConfiguration = [AppConstants.profileConfigurationKey: payload]

        manager.protocolConfiguration = tunnelProtocol
        manager.localizedDescription = "SwiftShield VPN"
        manager.isEnabled = true
        try await save(manager)
        try await reload(manager)
        self.manager = manager
        try manager.connection.startVPNTunnel()
        refreshStatus()
        #endif
    }

    func disconnect() async throws {
        manager?.connection.stopVPNTunnel()
        refreshStatus()
    }

    private func refreshStatus() {
        status = manager?.connection.status ?? .invalid
    }

    private func loadManager() async throws -> NETunnelProviderManager {
        let managers: [NETunnelProviderManager] = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[NETunnelProviderManager], Error>) in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: managers ?? []) }
            }
        }
        return managers.first ?? NETunnelProviderManager()
    }

    private func save(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    private func reload(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }
}

private enum TunnelControllerError: LocalizedError {
    case simulatorUnsupported

    var errorDescription: String? {
        "Системный VPN нельзя запустить в iPhone Simulator. Для проверки подключения выберите физический iPhone."
    }
}
