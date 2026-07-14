import Foundation

/// Reiner Netzwerk-Layer (MVVM: Service-Schicht) — kennt keine UI.
/// Ruft die Sensordaten asynchron vom Windows-Server ab.
struct MonitoringService {
    let baseURL: URL

    /// Kurzer Timeout, damit beim 1-Sekunden-Polling kein Rückstau
    /// aus hängenden Requests entsteht, wenn der PC nicht erreichbar ist.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private static let decoder = JSONDecoder()

    func fetchStats() async throws -> SystemStats {
        let url = baseURL.appending(path: "api/stats")
        let (data, response) = try await Self.session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try Self.decoder.decode(SystemStats.self, from: data)
    }
}
