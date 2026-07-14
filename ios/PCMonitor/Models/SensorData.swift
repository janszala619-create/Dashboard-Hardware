import Foundation

/// Entspricht 1:1 dem JSON von `GET /api/stats`.
/// Der Server liefert camelCase — kein Decoder-Mapping nötig.
struct SystemStats: Codable, Equatable {
    let timestamp: Double
    let gpu: GpuStats
    let cpu: CpuStats
}

struct GpuStats: Codable, Equatable {
    let name: String
    let load: Double         // %
    let temperature: Double  // °C
    let vramUsed: Int        // MB
    let vramTotal: Int       // MB
}

struct CpuStats: Codable, Equatable {
    let name: String
    let load: Double         // Gesamtauslastung in %
    let perCore: [Double]    // % je logischem Kern
}
