import Foundation

public struct SubscriptionParser: Sendable {
    private let profileParser = ProfileParser()

    public init() {}

    public func parse(_ input: String) throws -> [TunnelProfile] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProfileParserError.emptyInput }

        if let jsonProfiles = tryParseJSON(trimmed), !jsonProfiles.isEmpty {
            return uniqued(jsonProfiles)
        }

        let source: String
        if containsSupportedURI(trimmed) {
            source = trimmed
        } else if let data = decodeBase64(trimmed),
                  let decoded = String(data: data, encoding: .utf8),
                  containsSupportedURI(decoded) {
            source = decoded
        } else {
            throw ProfileParserError.unsupportedFormat
        }

        let profiles = source
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { try? profileParser.parse($0) }

        guard !profiles.isEmpty else { throw ProfileParserError.noProfiles }
        return uniqued(profiles)
    }

    private func containsSupportedURI(_ value: String) -> Bool {
        value.contains("vless://") || value.contains("trojan://") || value.contains("ss://")
    }

    private func uniqued(_ profiles: [TunnelProfile]) -> [TunnelProfile] {
        var fingerprints = Set<String>()
        return profiles.filter { profile in
            let fingerprint = "\(profile.kind.rawValue)|\(profile.server)|\(profile.port)|\(profile.userID ?? profile.password ?? "")"
            return fingerprints.insert(fingerprint).inserted
        }
    }

    private func tryParseJSON(_ value: String) -> [TunnelProfile]? {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        let dictionaries: [[String: Any]]
        if let root = object as? [String: Any], let outbounds = root["outbounds"] as? [[String: Any]] {
            dictionaries = outbounds
        } else if let array = object as? [[String: Any]] {
            dictionaries = array
        } else {
            return nil
        }

        return dictionaries.compactMap(profileFromJSON)
    }

    private func profileFromJSON(_ json: [String: Any]) -> TunnelProfile? {
        guard let type = (json["type"] as? String)?.lowercased(),
              let kind = TunnelProfile.Kind(rawValue: type),
              let server = json["server"] as? String,
              let port = json["server_port"] as? Int else {
            return nil
        }

        let tls = json["tls"] as? [String: Any]
        let reality = tls?["reality"] as? [String: Any]
        let transport = json["transport"] as? [String: Any]
        let transportType = transport?["type"] as? String ?? "tcp"
        let security: TunnelProfile.Security = reality?["enabled"] as? Bool == true
            ? .reality
            : (tls?["enabled"] as? Bool == true ? .tls : .none)

        return TunnelProfile(
            name: json["tag"] as? String ?? server,
            kind: kind,
            server: server,
            port: port,
            userID: json["uuid"] as? String,
            password: json["password"] as? String,
            cipher: json["method"] as? String,
            transport: TunnelProfile.Transport(rawValue: transportType) ?? .tcp,
            security: security,
            serverName: tls?["server_name"] as? String,
            publicKey: reality?["public_key"] as? String,
            shortID: reality?["short_id"] as? String,
            fingerprint: (tls?["utls"] as? [String: Any])?["fingerprint"] as? String,
            flow: json["flow"] as? String,
            path: transport?["path"] as? String,
            hostHeader: transport?["host"] as? String,
            originalURI: valueFromJSON(json)
        )
    }

    private func valueFromJSON(_ json: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
              let value = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return value
    }
}
