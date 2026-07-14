import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    gpuGauge
                    statGrid
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
        // automatisch gecancelt und die Schleife im ViewModel endet.
        .task { await viewModel.startPolling() }
    }

    // MARK: - GPU-Gauge

    private var gpuGauge: some View {
        VStack(spacing: 16) {
            Gauge(value: viewModel.stats?.gpu.load ?? 0, in: 0...100) {
                Text("GPU")
            } currentValueLabel: {
                Text("\(Int(viewModel.stats?.gpu.load ?? 0))%")
                    .font(.system(.body, design: .rounded).bold())
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
            .scaleEffect(2.4)
            .frame(width: 170, height: 170)

            Text(viewModel.stats?.gpu.name ?? "Warte auf Daten …")
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
                value: viewModel.stats.map { "\(Int($0.gpu.temperature)) °C" } ?? "–",
                icon: "thermometer.medium"
            )
            StatCard(
                title: "VRAM",
                value: viewModel.stats.map {
                    String(
                        format: "%.1f / %.0f GB",
                        Double($0.gpu.vramUsed) / 1024,
                        Double($0.gpu.vramTotal) / 1024
                    )
                } ?? "–",
                icon: "memorychip"
            )
            StatCard(
                title: "CPU-Last",
                value: viewModel.stats.map { "\(Int($0.cpu.load)) %" } ?? "–",
                icon: "cpu"
            )
            StatCard(
                title: "Kerne",
                value: viewModel.stats.map { "\($0.cpu.perCore.count)" } ?? "–",
                icon: "square.grid.2x2"
            )
        }
    }

    // MARK: - Verbindungsstatus

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(viewModel.isConnected ? "Online" : "Offline")
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
