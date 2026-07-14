import Foundation

/// Hält den UI-Zustand und pollt den Server im Sekundentakt (MVVM: ViewModel).
@MainActor
final class DashboardViewModel: ObservableObject {
    /// IP-Adresse des Windows-PCs im lokalen Netz — hier anpassen
    /// (auf dem PC per `ipconfig` ermitteln).
    @Published var host = "255.255.255.0"

    @Published private(set) var stats: SystemStats?
    @Published private(set) var isConnected = false

    /// Poll-Schleife. Wird über den `.task`-Modifier der View gestartet —
    /// verschwindet die View, cancelt SwiftUI den Task automatisch,
    /// und die Schleife endet über `Task.isCancelled`.
    func startPolling() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func refresh() async {
        guard let url = URL(string: "http://\(host):8000") else {
            isConnected = false
            return
        }
        do {
            stats = try await MonitoringService(baseURL: url).fetchStats()
            isConnected = true
        } catch {
            // Alte Werte stehen lassen, nur den Verbindungsstatus kippen —
            // so flackert das UI bei einem einzelnen verpassten Poll nicht.
            isConnected = false
        }
    }
}
