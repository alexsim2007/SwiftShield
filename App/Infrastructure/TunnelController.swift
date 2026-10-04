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
    private var activeProfile: TunnelProfile?
    private var connectedAt: Date?
    private var disconnectRequested = false
    private let liveActivity = LiveActivityController()

    var isActive: Bool {
        [.connected, .connecting, .reasserting, .disconnecting].contains(status)
    }

    var isTransitioning: Bool {
        [.connecting, .reasserting, .disconnecting].contains(status)
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
            activeProfile = profile(from: manager)
            liveActivity.restore()
            refreshStatus()
        } catch {
            status = .invalid
        }
    }

    func connect(profile: TunnelProfile, settings: TunnelSettings) async throws {
        #if targetEnvironment(simulator)
        throw TunnelControllerError.simulatorUnsupported
        #else
        isBusy = true
        defer { isBusy = false }
        activeProfile = profile
        connectedAt = nil
        disconnectRequested = false
        liveActivity.start(profile: profile)

        do {
            let manager = try await loadManager()
            let tunnelProtocol = NETunnelProviderProtocol()
            tunnelProtocol.providerBundleIdentifier = AppConstants.tunnelBundleIdentifier
            tunnelProtocol.serverAddress = profile.server
            tunnelProtocol.includeAllNetworks = true
            tunnelProtocol.excludeLocalNetworks = settings.bypassPrivateNetworks
            let profilePayload = try JSONEncoder().encode(profile).base64EncodedString()
            let settingsPayload = try JSONEncoder().encode(settings).base64EncodedString()
            tunnelProtocol.providerConfiguration = [
                AppConstants.profileConfigurationKey: profilePayload,
                AppConstants.settingsConfigurationKey: settingsPayload,
            ]

            manager.protocolConfiguration = tunnelProtocol
            manager.localizedDescription = "SwiftShield VPN"
            manager.isEnabled = true
            try await save(manager)
            try await reload(manager)
            self.manager = manager
            try manager.connection.startVPNTunnel()
            refreshStatus()
        } catch {
            liveActivity.end(profileName: profile.name)
            activeProfile = nil
            throw error
        }
        #endif
    }

    func disconnect() async throws {
        if manager == nil {
            manager = try await loadManager()
        }
        disconnectRequested = true
        if let activeProfile {
            liveActivity.update(
                status: "Отключение",
                profileName: activeProfile.name,
                connectedAt: connectedAt,
                isConnected: false
            )
        }
        manager?.connection.stopVPNTunnel()
        refreshStatus()
    }

    private func refreshStatus() {
        status = manager?.connection.status ?? .invalid
        syncLiveActivity()
    }

    private func syncLiveActivity() {
        guard let activeProfile else { return }
        switch status {
        case .connected:
            if disconnectRequested {
                liveActivity.update(
                    status: "Отключение",
                    profileName: activeProfile.name,
                    connectedAt: connectedAt,
                    isConnected: false
                )
                return
            }
            if connectedAt == nil { connectedAt = Date() }
            liveActivity.start(profile: activeProfile)
            liveActivity.update(
                status: statusTitle,
                profileName: activeProfile.name,
                connectedAt: connectedAt,
                isConnected: true
            )
        case .connecting, .reasserting, .disconnecting:
            liveActivity.update(
                status: statusTitle,
                profileName: activeProfile.name,
                connectedAt: connectedAt,
                isConnected: false
            )
        case .disconnected, .invalid:
            liveActivity.end(profileName: activeProfile.name)
            self.activeProfile = nil
            connectedAt = nil
            disconnectRequested = false
        @unknown default:
            break
        }
    }

    private func profile(from manager: NETunnelProviderManager?) -> TunnelProfile? {
        guard let tunnelProtocol = manager?.protocolConfiguration as? NETunnelProviderProtocol,
              let payload = tunnelProtocol.providerConfiguration?[AppConstants.profileConfigurationKey] as? String,
              let data = Data(base64Encoded: payload) else {
            return nil
        }
        return try? JSONDecoder().decode(TunnelProfile.self, from: data)
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
