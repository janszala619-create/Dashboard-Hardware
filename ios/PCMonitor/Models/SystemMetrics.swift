import Foundation

/// Exaktes Gegenstück zum Pydantic-Modell `SystemMetrics` des Servers.
/// Der Server liefert snake_case (`gpu_usage_percent`, …) — der Decoder
/// in MetricsService mappt das per .convertFromSnakeCase auf camelCase,
/// daher sind keine CodingKeys nötig.
struct SystemMetrics: Codable, Identifiable, Equatable {
    let timestamp: Double
    let cpuUsagePercent: Double
    let gpuUsagePercent: Double
    let gpuTempCelsius: Double
    let vramUsageGb: Double
    let vramTotalGb: Double

    /// Identifiable über den Messzeitpunkt. Computed Property —
    /// taucht dadurch nicht im Codable-Mapping auf.
    var id: Double { timestamp }
}
