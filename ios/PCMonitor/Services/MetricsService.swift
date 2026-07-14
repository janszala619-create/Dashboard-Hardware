import Foundation

/// Pollt den /metrics-Endpunkt des PCs im Sekundentakt und publiziert
/// die Werte für SwiftUI.
///
/// @MainActor garantiert, dass alle Updates der @Published-Properties
/// auf dem Main-Thread laufen — URLSession arbeitet im Hintergrund,
/// aber nach jedem `await` geht es hier auf dem MainActor weiter.
@MainActor
final class MetricsService: ObservableObject {
    /// IP-Adresse des Windows-PCs im lokalen Netz.
    @Published var host = "192.168.2.222"

    @Published private(set) var metrics: SystemMetrics?
    @Published private(set) var isConnected = false
    @Published private(set) var errorMessage: String?

    /// Ringpuffer der letzten Messungen für die Verlaufskurven.
    /// Bei 1 Messung/Sekunde entsprechen 120 Punkte ~2 Minuten.
    @Published private(set) var history: [SystemMetrics] = []
    private let historyLimit = 120

    /// Kurzer Timeout, damit sich beim 1-Sekunden-Polling keine
    /// hängenden Requests aufstauen, wenn der PC offline ist.
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// Poll-Schleife. Über den `.task`-Modifier der View gestartet —
    /// verschwindet die View, cancelt SwiftUI den Task automatisch
    /// und die Schleife endet über `Task.isCancelled`.
    func startPolling() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func refresh() async {
        guard let url = URL(string: "http://\(host):8000/metrics") else {
            fail("Ungültige Adresse: \(host)")
            return
        }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                fail("Serverfehler (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return
            }
            let decoded = try decoder.decode(SystemMetrics.self, from: data)
            metrics = decoded
            appendToHistory(decoded)
            isConnected = true
            errorMessage = nil
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                fail("Zeitüberschreitung — läuft der Server auf dem PC?")
            case .cannotConnectToHost, .cannotFindHost:
                fail("PC unter \(host):8000 nicht erreichbar")
            case .notConnectedToInternet, .networkConnectionLost:
                fail("Keine Netzwerkverbindung")
            case .cancelled:
                break  // View wurde verlassen — kein echter Fehler
            default:
                fail(error.localizedDescription)
            }
        } catch is DecodingError {
            fail("Unerwartetes Datenformat vom Server")
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func appendToHistory(_ entry: SystemMetrics) {
        history.append(entry)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }

    private func fail(_ message: String) {
        // Letzte bekannte Werte stehen lassen — nur der Status kippt.
        // So flackert das UI nicht, wenn ein einzelner Poll fehlschlägt.
        isConnected = false
        errorMessage = message
    }
}
