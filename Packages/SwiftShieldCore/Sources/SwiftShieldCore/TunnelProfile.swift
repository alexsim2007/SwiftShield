import Foundation

public struct TunnelProfile: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case vless
        case trojan
        case shadowsocks

        public var title: String {
            switch self {
            case .vless: return "VLESS"
            case .trojan: return "Trojan"
            case .shadowsocks: return "Shadowsocks"
            }
        }
    }

    public enum Transport: String, Codable, CaseIterable, Sendable {
        case tcp
        case websocket = "ws"
        case grpc
        case http
        case quic
    }

    public enum Security: String, Codable, CaseIterable, Sendable {
        case none
        case tls
        case reality
    }

    public let id: UUID
    public var name: String
    public var kind: Kind
    public var server: String
    public var port: Int
    public var userID: String?
    public var password: String?
    public var cipher: String?
    public var transport: Transport
    public var security: Security
    public var serverName: String?
    public var publicKey: String?
    public var shortID: String?
    public var fingerprint: String?
    public var flow: String?
    public var path: String?
    public var hostHeader: String?
    public var originalURI: String

    public init(
        id: UUID = UUID(),
        name: String,
        kind: Kind,
        server: String,
        port: Int,
        userID: String? = nil,
        password: String? = nil,
        cipher: String? = nil,
        transport: Transport = .tcp,
        security: Security = .none,
        serverName: String? = nil,
        publicKey: String? = nil,
        shortID: String? = nil,
        fingerprint: String? = nil,
        flow: String? = nil,
        path: String? = nil,
        hostHeader: String? = nil,
        originalURI: String
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.server = server
        self.port = port
        self.userID = userID
        self.password = password
        self.cipher = cipher
        self.transport = transport
        self.security = security
        self.serverName = serverName
        self.publicKey = publicKey
        self.shortID = shortID
        self.fingerprint = fingerprint
        self.flow = flow
        self.path = path
        self.hostHeader = hostHeader
        self.originalURI = originalURI
    }
}

