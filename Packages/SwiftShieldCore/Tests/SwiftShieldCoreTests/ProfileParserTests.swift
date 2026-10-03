import XCTest
@testable import SwiftShieldCore

final class ProfileParserTests: XCTestCase {
    func testParsesVLESSRealityProfile() throws {
        let uri = "vless://f455d0f4-ec4f-4f41-9d08-f25201fbe201@example.com:443?type=tcp&security=reality&sni=cdn.example.com&pbk=public-key&sid=ab12&fp=chrome#Moscow"
        let profile = try ProfileParser().parse(uri)

        XCTAssertEqual(profile.name, "Moscow")
        XCTAssertEqual(profile.kind, .vless)
        XCTAssertEqual(profile.server, "example.com")
        XCTAssertEqual(profile.port, 443)
        XCTAssertEqual(profile.security, .reality)
        XCTAssertEqual(profile.publicKey, "public-key")
    }

    func testParsesTrojanWebSocketProfile() throws {
        let uri = "trojan://secret@example.org:443?security=tls&type=ws&path=%2Fsocket#NL"
        let profile = try ProfileParser().parse(uri)

        XCTAssertEqual(profile.kind, .trojan)
        XCTAssertEqual(profile.password, "secret")
        XCTAssertEqual(profile.transport, .websocket)
        XCTAssertEqual(profile.path, "/socket")
    }

    func testParsesSIP002ShadowsocksProfile() throws {
        let credentials = Data("aes-256-gcm:password".utf8).base64EncodedString()
        let profile = try ProfileParser().parse("ss://\(credentials)@1.2.3.4:8388#Home")

        XCTAssertEqual(profile.kind, .shadowsocks)
        XCTAssertEqual(profile.cipher, "aes-256-gcm")
        XCTAssertEqual(profile.password, "password")
        XCTAssertEqual(profile.name, "Home")
    }

    func testParsesBase64SubscriptionAndRemovesDuplicates() throws {
        let uri = "vless://f455d0f4-ec4f-4f41-9d08-f25201fbe201@example.com:443?security=reality#One"
        let encoded = Data("\(uri)\n\(uri)".utf8).base64EncodedString()
        let profiles = try SubscriptionParser().parse(encoded)

        XCTAssertEqual(profiles.count, 1)
    }

    func testRejectsUnsupportedScheme() {
        XCTAssertThrowsError(try ProfileParser().parse("wireguard://example"))
    }
}

