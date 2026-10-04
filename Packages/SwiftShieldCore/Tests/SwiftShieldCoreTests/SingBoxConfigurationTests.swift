import XCTest
@testable import SwiftShieldCore

final class SingBoxConfigurationTests: XCTestCase {
    private let builder = SingBoxConfigurationBuilder()

    func testBuildsVLESSRealityConfiguration() throws {
        let profile = TunnelProfile(
            name: "Reality",
            kind: .vless,
            server: "vpn.example.com",
            port: 443,
            userID: "f455d0f4-ec4f-4f41-9d08-f25201fbe201",
            security: .reality,
            serverName: "cdn.example.com",
            publicKey: "public-key",
            shortID: "ab12",
            fingerprint: "chrome",
            flow: "xtls-rprx-vision",
            originalURI: "vless://example"
        )

        let root = try object(for: profile)
        let proxy = try XCTUnwrap((root["outbounds"] as? [[String: Any]])?.first)
        let tls = try XCTUnwrap(proxy["tls"] as? [String: Any])
        let reality = try XCTUnwrap(tls["reality"] as? [String: Any])

        XCTAssertEqual(proxy["type"] as? String, "vless")
        XCTAssertEqual(proxy["flow"] as? String, "xtls-rprx-vision")
        XCTAssertEqual(tls["server_name"] as? String, "cdn.example.com")
        XCTAssertEqual(reality["public_key"] as? String, "public-key")
    }

    func testBuildsTrojanWebSocketConfiguration() throws {
        let profile = TunnelProfile(
            name: "Trojan",
            kind: .trojan,
            server: "vpn.example.org",
            port: 443,
            password: "secret",
            transport: .websocket,
            security: .tls,
            path: "/socket",
            hostHeader: "edge.example.org",
            originalURI: "trojan://example"
        )

        let root = try object(for: profile)
        let proxy = try XCTUnwrap((root["outbounds"] as? [[String: Any]])?.first)
        let transport = try XCTUnwrap(proxy["transport"] as? [String: Any])
        let headers = try XCTUnwrap(transport["headers"] as? [String: String])

        XCTAssertEqual(proxy["password"] as? String, "secret")
        XCTAssertEqual(transport["type"] as? String, "ws")
        XCTAssertEqual(transport["path"] as? String, "/socket")
        XCTAssertEqual(headers["Host"], "edge.example.org")
    }

    func testBuildsShadowsocksConfigurationAndProtectedDNS() throws {
        let profile = TunnelProfile(
            name: "SS",
            kind: .shadowsocks,
            server: "1.2.3.4",
            port: 8388,
            password: "secret",
            cipher: "aes-256-gcm",
            originalURI: "ss://example"
        )

        let root = try object(for: profile)
        let proxy = try XCTUnwrap((root["outbounds"] as? [[String: Any]])?.first)
        let dns = try XCTUnwrap(root["dns"] as? [String: Any])
        let servers = try XCTUnwrap(dns["servers"] as? [[String: Any]])

        XCTAssertEqual(proxy["method"] as? String, "aes-256-gcm")
        XCTAssertEqual(servers.first?["detour"] as? String, "direct")
        XCTAssertEqual(servers.last?["detour"] as? String, "proxy")
        XCTAssertEqual(dns["final"] as? String, "remote")
    }

    func testRejectsRealityWithoutPublicKey() {
        let profile = TunnelProfile(
            name: "Broken",
            kind: .vless,
            server: "vpn.example.com",
            port: 443,
            userID: "f455d0f4-ec4f-4f41-9d08-f25201fbe201",
            security: .reality,
            originalURI: "vless://example"
        )

        XCTAssertThrowsError(try builder.makeConfiguration(for: profile)) { error in
            XCTAssertEqual(error as? SingBoxConfigurationError, .missingRealityPublicKey)
        }
    }

    func testAppliesAdvancedTunnelSettings() throws {
        let profile = TunnelProfile(
            name: "Advanced",
            kind: .vless,
            server: "vpn.example.com",
            port: 443,
            userID: "f455d0f4-ec4f-4f41-9d08-f25201fbe201",
            security: .tls,
            originalURI: "vless://advanced"
        )
        var settings = TunnelSettings()
        settings.multiplexEnabled = true
        settings.multiplexProtocol = .smux
        settings.multiplexPadding = true
        settings.tlsRecordFragmentationEnabled = true
        settings.tlsFragmentationEnabled = true
        settings.tlsFragmentFallbackDelayMilliseconds = 320
        settings.udpFragmentationEnabled = true
        settings.tcpFastOpenEnabled = true
        settings.packetEncoding = .xudp
        settings.dnsProvider = .quad9
        settings.tunMTU = 1500

        let root = try object(for: profile, settings: settings)
        let proxy = try XCTUnwrap((root["outbounds"] as? [[String: Any]])?.first)
        let multiplex = try XCTUnwrap(proxy["multiplex"] as? [String: Any])
        let tls = try XCTUnwrap(proxy["tls"] as? [String: Any])
        let dns = try XCTUnwrap(root["dns"] as? [String: Any])
        let servers = try XCTUnwrap(dns["servers"] as? [[String: Any]])
        let inbound = try XCTUnwrap((root["inbounds"] as? [[String: Any]])?.first)
        let route = try XCTUnwrap(root["route"] as? [String: Any])

        XCTAssertEqual(multiplex["protocol"] as? String, "smux")
        XCTAssertEqual(multiplex["max_connections"] as? Int, 4)
        XCTAssertEqual(multiplex["padding"] as? Bool, true)
        XCTAssertEqual(tls["fragment"] as? Bool, true)
        XCTAssertEqual(tls["record_fragment"] as? Bool, true)
        XCTAssertEqual(tls["fragment_fallback_delay"] as? String, "320ms")
        XCTAssertEqual(proxy["udp_fragment"] as? Bool, true)
        XCTAssertEqual(proxy["tcp_fast_open"] as? Bool, true)
        XCTAssertNil(proxy["network_strategy"])
        XCTAssertNil(route["default_network_strategy"])
        XCTAssertEqual(proxy["packet_encoding"] as? String, "xudp")
        XCTAssertEqual(servers.first?["server"] as? String, "9.9.9.9")
        XCTAssertEqual(inbound["mtu"] as? Int, 1500)
    }

    func testAppliesHybridNetworkStrategyWithoutTCPFastOpen() throws {
        let profile = TunnelProfile(
            name: "SS",
            kind: .shadowsocks,
            server: "1.2.3.4",
            port: 8388,
            password: "secret",
            cipher: "aes-256-gcm",
            originalURI: "ss://network"
        )
        var settings = TunnelSettings()
        settings.networkStrategy = .hybrid

        let root = try object(for: profile, settings: settings)
        let proxy = try XCTUnwrap((root["outbounds"] as? [[String: Any]])?.first)
        let route = try XCTUnwrap(root["route"] as? [String: Any])

        XCTAssertEqual(proxy["network_strategy"] as? String, "hybrid")
        XCTAssertEqual(route["default_network_strategy"] as? String, "hybrid")
    }

    func testCanProxyPrivateNetworksAndDisableSniffing() throws {
        let profile = TunnelProfile(
            name: "SS",
            kind: .shadowsocks,
            server: "1.2.3.4",
            port: 8388,
            password: "secret",
            cipher: "aes-256-gcm",
            originalURI: "ss://settings"
        )
        var settings = TunnelSettings()
        settings.bypassPrivateNetworks = false
        settings.sniffingEnabled = false

        let root = try object(for: profile, settings: settings)
        let route = try XCTUnwrap(root["route"] as? [String: Any])
        let rules = try XCTUnwrap(route["rules"] as? [[String: Any]])

        XCTAssertFalse(rules.contains { $0["ip_is_private"] as? Bool == true })
        XCTAssertFalse(rules.contains { $0["action"] as? String == "sniff" })
    }

    private func object(
        for profile: TunnelProfile,
        settings: TunnelSettings = TunnelSettings()
    ) throws -> [String: Any] {
        let configuration = try builder.makeConfiguration(for: profile, settings: settings)
        let data = try XCTUnwrap(configuration.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
