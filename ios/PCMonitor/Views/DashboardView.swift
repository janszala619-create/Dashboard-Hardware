import SwiftUI

struct DashboardView: View {
    @StateObject private var service = MetricsService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    gpuGauge
                    gpuSection
                    cpuSection
                    memorySection
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

            Text(service.metrics?.gpuName ?? "Warte auf Daten …")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sektionen

    private var gpuSection: some View {
        MetricsSection(title: "Grafikkarte") {
            StatCard(
                title: "Temperatur",
                value: service.metrics.map { "\(Int($0.gpuTempCelsius)) °C" } ?? "–",
                icon: "thermometer.medium"
            )
            StatCard(
                title: "Leistung",
                value: service.metrics.map {
                    "\(Int($0.gpuPowerWatts)) / \(Int($0.gpuPowerLimitWatts)) W"
                } ?? "–",
                icon: "bolt.fill"
            )
            StatCard(
                title: "GPU-Takt",
                value: service.metrics.map { "\(Int($0.gpuClockMhz)) MHz" } ?? "–",
                icon: "speedometer"
            )
            StatCard(
                title: "Speichertakt",
                value: service.metrics.map { "\(Int($0.gpuMemClockMhz)) MHz" } ?? "–",
                icon: "waveform"
            )
            StatCard(
                title: "Lüfter",
                value: service.metrics.map { "\(Int($0.gpuFanPercent)) %" } ?? "–",
                icon: "fanblades"
            )
            StatCard(
                title: "VRAM",
                value: service.metrics.map {
                    String(format: "%.1f / %.0f GB", $0.vramUsageGb, $0.vramTotalGb)
                } ?? "–",
                icon: "memorychip"
            )
        }
    }

    private var cpuSection: some View {
        MetricsSection(title: "Prozessor", subtitle: service.metrics?.cpuName) {
            StatCard(
                title: "Auslastung",
                value: service.metrics.map { "\(Int($0.cpuUsagePercent)) %" } ?? "–",
                icon: "cpu"
            )
            StatCard(
                title: "Takt",
                value: service.metrics.map { "\(Int($0.cpuFreqMhz)) MHz" } ?? "–",
                icon: "speedometer"
            )
        } footer: {
            if let cores = service.metrics?.cpuPerCorePercent, !cores.isEmpty {
                CoreLoadBars(loads: cores)
            }
        }
    }

    private var memorySection: some View {
        MetricsSection(title: "Arbeitsspeicher") {
            StatCard(
                title: "RAM",
                value: service.metrics.map {
                    String(format: "%.1f / %.0f GB", $0.ramUsageGb, $0.ramTotalGb)
                } ?? "–",
                icon: "memorychip.fill"
            )
            StatCard(
                title: "Belegung",
                value: service.metrics.map {
                    $0.ramTotalGb > 0
                        ? "\(Int($0.ramUsageGb / $0.ramTotalGb * 100)) %"
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

/// Sektion mit Überschrift, 2-spaltigem Kachel-Grid und optionalem Footer.
struct MetricsSection<Content: View, Footer: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                content
            }
            footer
        }
    }
}

/// Balkenanzeige der Auslastung je logischem CPU-Kern.
struct CoreLoadBars: View {
    let loads: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last je Kern")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(loads.enumerated()), id: \.offset) { index, load in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor(for: load))
                                .scaleEffect(
                                    y: max(load / 100, 0.03),
                                    anchor: .bottom
                                )
                        }
                        .frame(height: 56)
                        .animation(.easeOut(duration: 0.3), value: load)
                        Text("\(index + 1)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func barColor(for load: Double) -> Color {
        if load < 50 { return .green }
        if load < 80 { return .yellow }
        return .red
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
