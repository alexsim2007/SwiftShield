import Foundation

public enum SingBoxConfigurationError: LocalizedError, Equatable {
    case invalidServer
    case invalidPort
    case missingUserID
    case missingPassword
    case missingCipher
    case missingRealityPublicKey
    case serializationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidServer:
            return "В профиле не указан адрес сервера."
        case .invalidPort:
            return "В профиле указан неверный порт."
        case .missingUserID:
            return "В профиле VLESS отсутствует UUID."
        case .missingPassword:
            return "В профиле отсутствует пароль."
        case .missingCipher:
            return "В профиле Shadowsocks отсутствует метод шифрования."
        case .missingRealityPublicKey:
            return "В профиле Reality отсутствует публичный ключ."
        case .serializationFailed:
            return "Не удалось собрать конфигурацию sing-box."
        }
    }
}

public struct SingBoxConfigurationBuilder: Sendable {
    public init() {}

    public func makeConfiguration(
        for profile: TunnelProfile,
        settings: TunnelSettings = TunnelSettings()
    ) throws -> String {
        guard !profile.server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SingBoxConfigurationError.invalidServer
        }
        guard (1...65535).contains(profile.port) else {
            throw SingBoxConfigurationError.invalidPort
        }

        var dns: [String: Any] = [
            "servers": [
                [
                    "type": "udp",
                    "tag": "bootstrap",
                    "server": settings.dnsProvider.address,
                    "detour": "direct",
                ],
                [
                    "type": "https",
                    "tag": "remote",
                    "server": settings.dnsProvider.address,
                    "server_port": 443,
                    "path": "/dns-query",
                    "detour": "proxy",
                    "tls": [
                        "enabled": true,
                        "server_name": settings.dnsProvider.serverName,
                    ],
                ],
            ],
            "final": "remote",
            "disable_cache": !settings.dnsCacheEnabled,
        ]
        if !settings.ipStrategy.rawValue.isEmpty {
            dns["strategy"] = settings.ipStrategy.rawValue
        }

        var routeRules: [[String: Any]] = []
        if settings.sniffingEnabled {
            routeRules.append(["action": "sniff"])
        }
        routeRules.append(["protocol": "dns", "action": "hijack-dns"])
        if settings.bypassPrivateNetworks {
            routeRules.append(["ip_is_private": true, "outbound": "direct"])
        }

        var route: [String: Any] = [
            "rules": routeRules,
            "final": "proxy",
            "auto_detect_interface": true,
            "default_domain_resolver": "bootstrap",
        ]
        if settings.networkStrategy != .systemDefault && !settings.tcpFastOpenEnabled {
            route["default_network_strategy"] = settings.networkStrategy.rawValue
        }

        let configuration: [String: Any] = [
            "log": [
                "level": settings.logLevel.rawValue,
                "timestamp": true,
            ],
            "dns": dns,
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
                    "mtu": min(max(settings.tunMTU, 1280), 9000),
                    "auto_route": true,
                    "strict_route": true,
                ],
            ],
            "outbounds": [
                try makeProxyOutbound(profile, settings: settings),
                ["type": "direct", "tag": "direct"],
            ],
            "route": route,
        ]

        guard JSONSerialization.isValidJSONObject(configuration) else {
            throw SingBoxConfigurationError.serializationFailed
        }
        let data = try JSONSerialization.data(withJSONObject: configuration, options: [.sortedKeys])
        guard let result = String(data: data, encoding: .utf8) else {
            throw SingBoxConfigurationError.serializationFailed
        }
        return result
    }

    private func makeProxyOutbound(
        _ profile: TunnelProfile,
        settings: TunnelSettings
    ) throws -> [String: Any] {
        var outbound: [String: Any] = [
            "type": profile.kind.rawValue,
            "tag": "proxy",
            "server": profile.server,
            "server_port": profile.port,
            "domain_resolver": "bootstrap",
            "tcp_fast_open": settings.tcpFastOpenEnabled,
            "udp_fragment": settings.udpFragmentationEnabled,
        ]
        if settings.networkStrategy != .systemDefault && !settings.tcpFastOpenEnabled {
            outbound["network_strategy"] = settings.networkStrategy.rawValue
        }

        switch profile.kind {
        case .vless:
            guard let userID = nonEmpty(profile.userID) else {
                throw SingBoxConfigurationError.missingUserID
            }
            outbound["uuid"] = userID
            if let flow = nonEmpty(profile.flow) {
                outbound["flow"] = flow
            }
            if settings.packetEncoding != .none {
                outbound["packet_encoding"] = settings.packetEncoding.rawValue
            }
        case .trojan:
            guard let password = nonEmpty(profile.password) else {
                throw SingBoxConfigurationError.missingPassword
            }
            outbound["password"] = password
        case .shadowsocks:
            guard let password = nonEmpty(profile.password) else {
                throw SingBoxConfigurationError.missingPassword
            }
            guard let cipher = nonEmpty(profile.cipher) else {
                throw SingBoxConfigurationError.missingCipher
            }
            outbound["password"] = password
            outbound["method"] = cipher
        }

        if let tls = try makeTLS(profile, settings: settings) {
            outbound["tls"] = tls
        }
        if let transport = makeTransport(profile) {
            outbound["transport"] = transport
        }
        if settings.multiplexEnabled {
            var multiplex: [String: Any] = [
                "enabled": true,
                "protocol": settings.multiplexProtocol.rawValue,
                "padding": settings.multiplexPadding,
            ]
            switch settings.multiplexLimit {
            case .connections:
                multiplex["max_connections"] = min(max(settings.multiplexMaxConnections, 1), 32)
                multiplex["min_streams"] = min(max(settings.multiplexMinStreams, 1), 64)
            case .streams:
                multiplex["max_streams"] = min(max(settings.multiplexMaxStreams, 1), 256)
            }
            outbound["multiplex"] = multiplex
        }
        return outbound
    }

    private func makeTLS(
        _ profile: TunnelProfile,
        settings: TunnelSettings
    ) throws -> [String: Any]? {
        guard profile.security != .none else { return nil }

        var tls: [String: Any] = [
            "enabled": true,
            "server_name": nonEmpty(profile.serverName) ?? profile.server,
            "fragment": settings.tlsFragmentationEnabled,
            "record_fragment": settings.tlsRecordFragmentationEnabled,
        ]
        if settings.tlsFragmentationEnabled {
            let delay = min(max(settings.tlsFragmentFallbackDelayMilliseconds, 20), 5_000)
            tls["fragment_fallback_delay"] = "\(delay)ms"
        }
        if let fingerprint = nonEmpty(profile.fingerprint) {
            tls["utls"] = [
                "enabled": true,
                "fingerprint": fingerprint,
            ]
        }
        if profile.security == .reality {
            guard let publicKey = nonEmpty(profile.publicKey) else {
                throw SingBoxConfigurationError.missingRealityPublicKey
            }
            var reality: [String: Any] = [
                "enabled": true,
                "public_key": publicKey,
            ]
            if let shortID = nonEmpty(profile.shortID) {
                reality["short_id"] = shortID
            }
            tls["reality"] = reality
            if tls["utls"] == nil {
                tls["utls"] = [
                    "enabled": true,
                    "fingerprint": "chrome",
                ]
            }
        }
        return tls
    }

    private func makeTransport(_ profile: TunnelProfile) -> [String: Any]? {
        switch profile.transport {
        case .tcp:
            return nil
        case .websocket:
            var transport: [String: Any] = [
                "type": "ws",
                "path": nonEmpty(profile.path) ?? "/",
            ]
            if let host = nonEmpty(profile.hostHeader) {
                transport["headers"] = ["Host": host]
            }
            return transport
        case .grpc:
            var transport: [String: Any] = ["type": "grpc"]
            if let serviceName = nonEmpty(profile.path) {
                transport["service_name"] = serviceName
            }
            return transport
        case .http:
            var transport: [String: Any] = [
                "type": "http",
                "path": nonEmpty(profile.path) ?? "/",
            ]
            if let host = nonEmpty(profile.hostHeader) {
                transport["host"] = [host]
            }
            return transport
        case .quic:
            return ["type": "quic"]
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        let value = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
