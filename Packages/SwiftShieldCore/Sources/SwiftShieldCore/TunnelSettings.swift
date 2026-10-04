import Foundation

public struct TunnelSettings: Codable, Equatable, Sendable {
    public enum MultiplexProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
        case h2mux
        case smux
        case yamux

        public var id: String { rawValue }
    }

    public enum MultiplexLimit: String, Codable, CaseIterable, Identifiable, Sendable {
        case connections
        case streams

        public var id: String { rawValue }
    }

    public enum PacketEncoding: String, Codable, CaseIterable, Identifiable, Sendable {
        case none
        case xudp
        case packetAddress = "packetaddr"

        public var id: String { rawValue }
    }

    public enum IPStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
        case automatic = ""
        case preferIPv4 = "prefer_ipv4"
        case preferIPv6 = "prefer_ipv6"
        case ipv4Only = "ipv4_only"
        case ipv6Only = "ipv6_only"

        public var id: String { rawValue }
    }

    public enum NetworkStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
        case systemDefault = "default"
        case hybrid
        case fallback

        public var id: String { rawValue }
    }

    public enum DNSProvider: String, Codable, CaseIterable, Identifiable, Sendable {
        case cloudflare
        case google
        case quad9

        public var id: String { rawValue }

        public var address: String {
            switch self {
            case .cloudflare: return "1.1.1.1"
            case .google: return "8.8.8.8"
            case .quad9: return "9.9.9.9"
            }
        }

        public var serverName: String {
            switch self {
            case .cloudflare: return "cloudflare-dns.com"
            case .google: return "dns.google"
            case .quad9: return "dns.quad9.net"
            }
        }
    }

    public enum LogLevel: String, Codable, CaseIterable, Identifiable, Sendable {
        case error
        case warn
        case info
        case debug

        public var id: String { rawValue }
    }

    public var multiplexEnabled: Bool
    public var multiplexProtocol: MultiplexProtocol
    public var multiplexLimit: MultiplexLimit
    public var multiplexMaxConnections: Int
    public var multiplexMinStreams: Int
    public var multiplexMaxStreams: Int
    public var multiplexPadding: Bool
    public var tlsRecordFragmentationEnabled: Bool
    public var tlsFragmentationEnabled: Bool
    public var tlsFragmentFallbackDelayMilliseconds: Int
    public var udpFragmentationEnabled: Bool
    public var tcpFastOpenEnabled: Bool
    public var packetEncoding: PacketEncoding
    public var ipStrategy: IPStrategy
    public var networkStrategy: NetworkStrategy
    public var dnsProvider: DNSProvider
    public var dnsCacheEnabled: Bool
    public var sniffingEnabled: Bool
    public var bypassPrivateNetworks: Bool
    public var tunMTU: Int
    public var logLevel: LogLevel

    public init(
        multiplexEnabled: Bool = false,
        multiplexProtocol: MultiplexProtocol = .h2mux,
        multiplexLimit: MultiplexLimit = .connections,
        multiplexMaxConnections: Int = 4,
        multiplexMinStreams: Int = 4,
        multiplexMaxStreams: Int = 16,
        multiplexPadding: Bool = false,
        tlsRecordFragmentationEnabled: Bool = false,
        tlsFragmentationEnabled: Bool = false,
        tlsFragmentFallbackDelayMilliseconds: Int = 500,
        udpFragmentationEnabled: Bool = false,
        tcpFastOpenEnabled: Bool = false,
        packetEncoding: PacketEncoding = .xudp,
        ipStrategy: IPStrategy = .preferIPv4,
        networkStrategy: NetworkStrategy = .systemDefault,
        dnsProvider: DNSProvider = .cloudflare,
        dnsCacheEnabled: Bool = true,
        sniffingEnabled: Bool = true,
        bypassPrivateNetworks: Bool = true,
        tunMTU: Int = 9000,
        logLevel: LogLevel = .info
    ) {
        self.multiplexEnabled = multiplexEnabled
        self.multiplexProtocol = multiplexProtocol
        self.multiplexLimit = multiplexLimit
        self.multiplexMaxConnections = multiplexMaxConnections
        self.multiplexMinStreams = multiplexMinStreams
        self.multiplexMaxStreams = multiplexMaxStreams
        self.multiplexPadding = multiplexPadding
        self.tlsRecordFragmentationEnabled = tlsRecordFragmentationEnabled
        self.tlsFragmentationEnabled = tlsFragmentationEnabled
        self.tlsFragmentFallbackDelayMilliseconds = tlsFragmentFallbackDelayMilliseconds
        self.udpFragmentationEnabled = udpFragmentationEnabled
        self.tcpFastOpenEnabled = tcpFastOpenEnabled
        self.packetEncoding = packetEncoding
        self.ipStrategy = ipStrategy
        self.networkStrategy = networkStrategy
        self.dnsProvider = dnsProvider
        self.dnsCacheEnabled = dnsCacheEnabled
        self.sniffingEnabled = sniffingEnabled
        self.bypassPrivateNetworks = bypassPrivateNetworks
        self.tunMTU = tunMTU
        self.logLevel = logLevel
    }
}
