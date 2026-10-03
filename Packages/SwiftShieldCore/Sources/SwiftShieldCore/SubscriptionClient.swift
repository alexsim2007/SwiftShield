import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor SubscriptionClient {
    public enum ClientError: LocalizedError {
        case invalidURL
        case insecureURL
        case invalidResponse
        case responseTooLarge
        case unreadableResponse

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Проверьте адрес подписки."
            case .insecureURL: return "Подписка должна использовать HTTPS."
            case .invalidResponse: return "Сервер подписки вернул ошибку."
            case .responseTooLarge: return "Ответ подписки слишком большой."
            case .unreadableResponse: return "Не удалось прочитать ответ подписки."
            }
        }
    }

    private let session: URLSession
    private let maxBytes = 5 * 1_024 * 1_024

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpAdditionalHeaders = ["User-Agent": "SwiftShield/0.1"]
        self.session = URLSession(configuration: configuration)
    }

    public func fetch(from rawURL: String) async throws -> String {
        guard let url = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ClientError.invalidURL
        }
        guard url.scheme?.lowercased() == "https" else {
            throw ClientError.insecureURL
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ClientError.invalidResponse
        }
        guard data.count <= maxBytes else { throw ClientError.responseTooLarge }
        guard let value = String(data: data, encoding: .utf8) else {
            throw ClientError.unreadableResponse
        }
        return value
    }
}

