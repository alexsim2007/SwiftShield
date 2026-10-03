import Foundation

public actor SharedProfileStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil) throws {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = try Self.defaultFileURL()
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    private static func defaultFileURL() throws -> URL {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
        ) {
            return container.appendingPathComponent("profiles.json", isDirectory: false)
        }

        #if targetEnvironment(simulator)
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("SwiftShield", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("profiles.json", isDirectory: false)
        #else
        throw StoreError.appGroupUnavailable
        #endif
    }

    public func load() throws -> [TunnelProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try decoder.decode([TunnelProfile].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ profiles: [TunnelProfile]) throws {
        let data = try encoder.encode(profiles)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    public enum StoreError: LocalizedError {
        case appGroupUnavailable

        public var errorDescription: String? {
            "App Group для SwiftShield недоступен. Проверьте подпись и capabilities проекта."
        }
    }
}
