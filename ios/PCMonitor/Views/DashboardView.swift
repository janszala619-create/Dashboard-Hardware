import SwiftUI

struct DashboardView: View {
    @StateObject private var service = MetricsService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    gpuGauge
                    statGrid
                    errorBanner
                }
                .padding()
            }
            .navigationTitle("PC Monitor")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    connectionBadge
                }
            }
        }
        // Startet das Polling; beim Verlassen der View wird der Task
        // automatisch gecancelt und die Schleife im Service endet.
        .task { await service.startPolling() }
    }

    // MARK: - GPU-Gauge

    private var gpuGauge: some View {
        VStack(spacing: 16) {
            Gauge(value: service.metrics?.gpuUsagePercent ?? 0, in: 0...100) {
                Text("GPU")
            } currentValueLabel: {
                Text("\(Int(service.metrics?.gpuUsagePercent ?? 0))%")
                    .font(.system(.body, design: .rounded).bold())
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
            .scaleEffect(2.4)
            .frame(width: 170, height: 170)

            Text(service.isConnected ? "Verbunden mit \(service.host)" : "Warte auf Daten …")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stat-Karten

    private var statGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            StatCard(
                title: "GPU-Temp",
                value: service.metrics.map { "\(Int($0.gpuTempCelsius)) °C" } ?? "–",
                icon: "thermometer.medium"
            )
            StatCard(
                title: "CPU-Last",
                value: service.metrics.map { "\(Int($0.cpuUsagePercent)) %" } ?? "–",
                icon: "cpu"
            )
            StatCard(
                title: "VRAM",
                value: service.metrics.map {
                    String(format: "%.1f / %.0f GB", $0.vramUsageGb, $0.vramTotalGb)
                } ?? "–",
                icon: "memorychip"
            )
            StatCard(
                title: "VRAM-Auslastung",
                value: service.metrics.map {
                    $0.vramTotalGb > 0
                        ? "\(Int($0.vramUsageGb / $0.vramTotalGb * 100)) %"
                        : "–"
                } ?? "–",
                icon: "gauge.with.dots.needle.50percent"
            )
        }
    }

    // MARK: - Fehleranzeige

    @ViewBuilder
    private var errorBanner: some View {
        if let message = service.errorMessage {
            Label(message, systemImage: "wifi.exclamationmark")
                .font(.footnote)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Verbindungsstatus

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(service.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(service.isConnected ? "Online" : "Offline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Wiederverwendbare Kachel für einen einzelnen Messwert.
struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded).bold())
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    DashboardView()
}
