import Charts
import SwiftUI

/// Eine Messreihe für die Verlaufskurve: Name, Farbe und der KeyPath
/// auf das jeweilige Feld in SystemMetrics.
struct SeriesSpec: Identifiable {
    let name: String
    let color: Color
    let keyPath: KeyPath<SystemMetrics, Double>

    var id: String { name }
}

/// Kachel mit einer Swift-Charts-Verlaufskurve über die gesammelte
/// Historie. Bei einer einzelnen Serie wird die Fläche unter der Kurve
/// gefüllt, bei mehreren Serien erscheint automatisch eine Legende.
struct HistoryChartCard: View {
    let title: String
    let series: [SeriesSpec]
    let history: [SystemMetrics]
    var yDomain: ClosedRange<Double>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if history.count < 2 {
                Text("Sammle Daten …")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                chart
                    .frame(height: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var chart: some View {
        Chart {
            // Gefüllte Fläche nur bei einer einzelnen Serie —
            // bei mehreren würden sich die Flächen überlagern.
            if series.count == 1, let spec = series.first {
                ForEach(history) { entry in
                    AreaMark(
                        x: .value("Zeit", date(of: entry)),
                        y: .value(spec.name, entry[keyPath: spec.keyPath])
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [spec.color.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }

            ForEach(series) { spec in
                ForEach(history) { entry in
                    LineMark(
                        x: .value("Zeit", date(of: entry)),
                        y: .value(spec.name, entry[keyPath: spec.keyPath]),
                        series: .value("Serie", spec.name)
                    )
                    .foregroundStyle(by: .value("Serie", spec.name))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
        }
        .chartForegroundStyleScale(
            domain: series.map(\.name),
            range: series.map(\.color)
        )
        .chartLegend(series.count > 1 ? .visible : .hidden)
        .chartXAxis(.hidden)
        .chartYScale(domain: yDomain ?? automaticDomain)
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
    }

    private func date(of entry: SystemMetrics) -> Date {
        Date(timeIntervalSince1970: entry.timestamp)
    }

    /// Ohne feste Vorgabe: 0 bis knapp über das Maximum der Historie,
    /// damit die Kurve nicht am oberen Rand klebt.
    private var automaticDomain: ClosedRange<Double> {
        let maxValue = series
            .flatMap { spec in history.map { $0[keyPath: spec.keyPath] } }
            .max() ?? 1
        return 0...max(maxValue * 1.15, 1)
    }
}
