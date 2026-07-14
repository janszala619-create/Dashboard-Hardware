import Foundation

/// Exaktes Gegenstück zum Pydantic-Modell `SystemMetrics` des Servers.
/// Der Server liefert snake_case (`gpu_usage_percent`, …) — der Decoder
/// in MetricsService mappt das per .convertFromSnakeCase auf camelCase,
/// daher sind keine CodingKeys nötig.
struct SystemMetrics: Codable, Identifiable, Equatable {
    let timestamp: Double

    // CPU
    let cpuName: String
    let cpuUsagePercent: Double
    let cpuPerCorePercent: [Double]
    let cpuFreqMhz: Double

    // GPU
    let gpuName: String
    let gpuUsagePercent: Double
    let gpuTempCelsius: Double
    let gpuPowerWatts: Double
    let gpuPowerLimitWatts: Double
    let gpuClockMhz: Double
    let gpuMemClockMhz: Double
    let gpuFanPercent: Double

    // Speicher
    let vramUsageGb: Double
    let vramTotalGb: Double
    let ramUsageGb: Double
    let ramTotalGb: Double

    /// Identifiable über den Messzeitpunkt. Computed Property —
    /// taucht dadurch nicht im Codable-Mapping auf.
    var id: Double { timestamp }
}
