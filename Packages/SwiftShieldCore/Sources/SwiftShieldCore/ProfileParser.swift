import Foundation

public enum ProfileParserError: LocalizedError, Equatable {
    case emptyInput
    case unsupportedFormat
    case invalidURI
    case missingServer
    case invalidPort
    case missingCredential
    case noProfiles

    public var errorDescription: String? {
        switch self {
        case .emptyInput: return "Вставьте ключ или содержимое подписки."
        case .unsupportedFormat: return "Этот формат пока не поддерживается."
        case .invalidURI: return "Ссылка профиля повреждена."
        case .missingServer: return "В профиле не указан адрес сервера."
        case .invalidPort: return "В профиле указан неверный порт."
        case .missingCredential: return "В профиле не хватает ключа или пароля."
        case .noProfiles: return "В подписке не найдено поддерживаемых профилей."
        }
    }
}

public struct ProfileParser: Sendable {
    public init() {}

    public func parse(_ input: String) throws -> TunnelProfile {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ProfileParserError.emptyInput }

        let scheme = value.prefix { $0 != ":" }.lowercased()
        switch scheme {
        case "vless": return try parseVLESS(value)
        case "trojan": return try parseTrojan(value)
        case "ss": return try parseShadowsocks(value)
        default: throw ProfileParserError.unsupportedFormat
        }
    }

    private func parseVLESS(_ value: String) throws -> TunnelProfile {
        guard let parts = URLComponents(string: value) else {
            throw ProfileParserError.invalidURI
        }
        let endpoint = try endpoint(from: parts)
        guard let userID = decoded(parts.user), !userID.isEmpty else {
            throw ProfileParserError.missingCredential
        }
        let query = queryItems(parts)

        return TunnelProfile(
            name: profileName(parts.fragment, fallback: endpoint.host),
            kind: .vless,
            server: endpoint.host,
            port: endpoint.port,
            userID: userID,
            transport: transport(query["type"]),
            security: security(query["security"]),
            serverName: query["sni"],
            publicKey: query["pbk"],
            shortID: query["sid"],
            fingerprint: query["fp"],
            flow: query["flow"],
            path: query["path"],
            hostHeader: query["host"],
            originalURI: value
        )
    }

    private func parseTrojan(_ value: String) throws -> TunnelProfile {
        guard let parts = URLComponents(string: value) else {
            throw ProfileParserError.invalidURI
        }
        let endpoint = try endpoint(from: parts)
        guard let password = decoded(parts.user), !password.isEmpty else {
            throw ProfileParserError.missingCredential
        }
        let query = queryItems(parts)

        return TunnelProfile(
            name: profileName(parts.fragment, fallback: endpoint.host),
            kind: .trojan,
            server: endpoint.host,
            port: endpoint.port,
            password: password,
            transport: transport(query["type"]),
            security: security(query["security"] ?? "tls"),
            serverName: query["sni"],
            fingerprint: query["fp"],
            path: query["path"],
            hostHeader: query["host"],
            originalURI: value
        )
    }

    private func parseShadowsocks(_ value: String) throws -> TunnelProfile {
        let withoutScheme = String(value.dropFirst("ss://".count))
        let splitFragment = withoutScheme.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let payload = String(splitFragment[0]).split(separator: "?", maxSplits: 1).first.map(String.init) ?? ""
        let name = splitFragment.count > 1 ? decoded(String(splitFragment[1])) : nil

        let normalized: String
        if payload.contains("@") {
            normalized = payload
        } else if let data = decodeBase64(payload), let decodedValue = String(data: data, encoding: .utf8) {
            normalized = decodedValue
        } else {
            throw ProfileParserError.invalidURI
        }

        guard let at = normalized.lastIndex(of: "@") else {
            throw ProfileParserError.invalidURI
        }
        var credentials = String(normalized[..<at])
        let address = String(normalized[normalized.index(after: at)...])
        if !credentials.contains(":"),
           let data = decodeBase64(credentials),
           let decodedCredentials = String(data: data, encoding: .utf8) {
            credentials = decodedCredentials
        }

        guard let separator = credentials.firstIndex(of: ":") else {
            throw ProfileParserError.missingCredential
        }
        let cipher = String(credentials[..<separator])
        let password = String(credentials[credentials.index(after: separator)...])
        guard !cipher.isEmpty, !password.isEmpty else {
            throw ProfileParserError.missingCredential
        }

        let endpoint = try parseAddress(address)
        return TunnelProfile(
            name: profileName(name, fallback: endpoint.host),
            kind: .shadowsocks,
            server: endpoint.host,
            port: endpoint.port,
            password: decoded(password),
            cipher: decoded(cipher),
            originalURI: value
        )
    }

    private func endpoint(from components: URLComponents) throws -> (host: String, port: Int) {
        guard let host = components.host, !host.isEmpty else {
            throw ProfileParserError.missingServer
        }
        guard let port = components.port, (1...65535).contains(port) else {
            throw ProfileParserError.invalidPort
        }
        return (host, port)
    }

    private func parseAddress(_ address: String) throws -> (host: String, port: Int) {
        guard let components = URLComponents(string: "ss://\(address)") else {
            throw ProfileParserError.invalidURI
        }
        return try endpoint(from: components)
    }

    private func queryItems(_ components: URLComponents) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name.lowercased(), value)
        })
    }

    private func transport(_ value: String?) -> TunnelProfile.Transport {
        TunnelProfile.Transport(rawValue: value?.lowercased() ?? "tcp") ?? .tcp
    }

    private func security(_ value: String?) -> TunnelProfile.Security {
        TunnelProfile.Security(rawValue: value?.lowercased() ?? "none") ?? .none
    }

    private func profileName(_ value: String?, fallback: String) -> String {
        let candidate = decoded(value)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate?.isEmpty == false ? candidate! : fallback
    }

    private func decoded(_ value: String?) -> String? {
        value?.removingPercentEncoding ?? value
    }
}

public func decodeBase64(_ value: String) -> Data? {
    let urlSafe = value
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
        .filter { !$0.isWhitespace }
    let remainder = urlSafe.count % 4
    let padded = remainder == 0 ? urlSafe : urlSafe + String(repeating: "=", count: 4 - remainder)
    return Data(base64Encoded: padded, options: .ignoreUnknownCharacters)
}

