import Foundation
import NetworkExtension
import SwiftShieldCore

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var engine: LibboxTunnelEngine?

    override func startTunnel(
        options: [String: NSObject]? = nil,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            let profile = try loadProfile()
            let settings = try loadSettings()
            let engine = LibboxTunnelEngine(provider: self)
            self.engine = engine
            try engine.start(profile: profile, settings: settings)
            completionHandler(nil)
        } catch {
            engine?.shutdown()
            engine = nil
            completionHandler(error)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        engine?.shutdown()
        engine = nil
        completionHandler()
    }

    func stopService() {
        engine?.stopService()
    }

    func reloadService() throws {
        try engine?.reloadService()
    }

    private func loadProfile() throws -> TunnelProfile {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
              let payload = tunnelProtocol.providerConfiguration?[AppConstants.profileConfigurationKey] as? String,
              let data = Data(base64Encoded: payload) else {
            throw TunnelExtensionError.missingProfile
        }
        do {
            return try JSONDecoder().decode(TunnelProfile.self, from: data)
        } catch {
            throw TunnelExtensionError.invalidProfile(error.localizedDescription)
        }
    }

    private func loadSettings() throws -> TunnelSettings {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
              let payload = tunnelProtocol.providerConfiguration?[AppConstants.settingsConfigurationKey] as? String,
              let data = Data(base64Encoded: payload) else {
            return TunnelSettings()
        }
        do {
            return try JSONDecoder().decode(TunnelSettings.self, from: data)
        } catch {
            throw TunnelExtensionError.invalidSettings(error.localizedDescription)
        }
    }
}

enum TunnelExtensionError: LocalizedError {
    case missingProfile
    case invalidProfile(String)
    case invalidSettings(String)
    case missingSharedContainer
    case libboxSetup(String)
    case invalidConfiguration(String)
    case commandServer(String)
    case service(String)
    case missingTunnelOptions
    case missingTunnelFileDescriptor

    var errorDescription: String? {
        switch self {
        case .missingProfile:
            return "SwiftShield не получил профиль туннеля."
        case let .invalidProfile(message):
            return "Профиль туннеля повреждён: \(message)"
        case let .invalidSettings(message):
            return "Настройки туннеля повреждены: \(message)"
        case .missingSharedContainer:
            return "SwiftShield не получил доступ к общей App Group."
        case let .libboxSetup(message):
            return "Не удалось подготовить sing-box: \(message)"
        case let .invalidConfiguration(message):
            return "Конфигурация sing-box отклонена: \(message)"
        case let .commandServer(message):
            return "Не удалось запустить управление sing-box: \(message)"
        case let .service(message):
            return "Не удалось запустить VPN-ядро: \(message)"
        case .missingTunnelOptions:
            return "sing-box не передал параметры TUN."
        case .missingTunnelFileDescriptor:
            return "iOS не предоставила файловый дескриптор TUN."
        }
    }
}
