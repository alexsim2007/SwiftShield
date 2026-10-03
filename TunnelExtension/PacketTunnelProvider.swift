import Foundation
import NetworkExtension
import SwiftShieldCore

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var engine: TunnelEngine?

    override func startTunnel(
        options: [String: NSObject]? = nil,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            let profile = try loadProfile()
            let engine = EngineFactory.make(packetFlow: packetFlow)
            self.engine = engine
            try engine.start(profile: profile) {
                completionHandler(nil)
            }
        } catch {
            completionHandler(error)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        engine?.stop()
        engine = nil
        completionHandler()
    }

    private func loadProfile() throws -> TunnelProfile {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
              let payload = tunnelProtocol.providerConfiguration?[AppConstants.profileConfigurationKey] as? String,
              let data = Data(base64Encoded: payload) else {
            throw TunnelError.missingProfile
        }
        return try JSONDecoder().decode(TunnelProfile.self, from: data)
    }
}

private protocol TunnelEngine: AnyObject {
    func start(profile: TunnelProfile, completion: @escaping () -> Void) throws
    func stop()
}

private enum EngineFactory {
    static func make(packetFlow: NEPacketTunnelFlow) -> TunnelEngine {
        UnavailableTunnelEngine()
    }
}

private final class UnavailableTunnelEngine: TunnelEngine {
    func start(profile: TunnelProfile, completion: @escaping () -> Void) throws {
        throw TunnelError.engineUnavailable
    }

    func stop() {}
}

private enum TunnelError: LocalizedError {
    case missingProfile
    case engineUnavailable

    var errorDescription: String? {
        switch self {
        case .missingProfile:
            return "SwiftShield не получил профиль туннеля."
        case .engineUnavailable:
            return "Libbox.xcframework ещё не подключён к TunnelExtension."
        }
    }
}
