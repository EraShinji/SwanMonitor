import SwiftUI
import Charts

struct MetricChartView: View {
    let data: MetricChartData
    var interactive = false

    var body: some View {
        Chart {
            // Vectorized plots avoid a separate SwiftUI mark tree for every point.
            AreaPlot(data.points, x: .value("Step", \.index),
                     yStart: .value(String(localized: "数值"), data.bounds.lowerBound),
                     yEnd: .value(String(localized: "数值"), \.value))
                .interpolationMethod(.linear)
                .foregroundStyle(LinearGradient(
                    colors: [Color.teal.opacity(0.3), Color.teal.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
                .accessibilityHidden(true)
            LinePlot(data.points, x: .value("Step", \.index),
                     y: .value(String(localized: "数值"), \.value))
                .interpolationMethod(.linear)
                .foregroundStyle(.teal)
                .lineStyle(StrokeStyle(lineWidth: 1.8))
            if data.points.count == 1, let point = data.points.first {
                PointMark(x: .value("Step", point.index), y: .value(String(localized: "数值"), point.value))
                    .foregroundStyle(.teal)
            }
        }
        .chartYScale(domain: data.bounds)
        .chartYAxis { AxisMarks(position: .leading) }
        .chartOverlay { proxy in
            if interactive {
                MetricChartInteraction(data: data, proxy: proxy).id(data.id)
            }
        }
    }
}

// Selection state stays outside the full-series chart: dragging only updates this
// lightweight overlay, rather than restyling/rebuilding the line and area.
private struct MetricChartInteraction: View {
    let data: MetricChartData
    let proxy: ChartProxy
    @State private var selected: MetricChartSample?

    var body: some View {
        GeometryReader { geometry in
            if let frame = proxy.plotFrame {
                let plot = geometry[frame]
                ZStack(alignment: .topLeading) {
                    if let selected,
                       let x = proxy.position(forX: selected.index),
                       let y = proxy.position(forY: selected.value) {
                        Path { path in
                            path.move(to: CGPoint(x: plot.minX + x, y: plot.minY))
                            path.addLine(to: CGPoint(x: plot.minX + x, y: plot.maxY))
                        }
                        .stroke(Color.blue.opacity(0.7), lineWidth: 1)
                        Circle().fill(.blue).frame(width: 8, height: 8)
                            .position(x: plot.minX + x, y: plot.minY + y)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Step \(selected.index.formatted(.number.precision(.significantDigits(1...17))))")
                            Text(selected.value.formatted(.number.precision(.significantDigits(1...17))))
                                .fontWeight(.semibold)
                        }
                        .font(.caption).padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .allowsHitTesting(false)
                    }
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(LongPressGesture(minimumDuration: 0.3)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                guard case .second(true, let drag?) = value else { return }
                                let x = min(max(drag.location.x - plot.minX, 0), plot.width)
                                if let step: Double = proxy.value(atX: x), let point = data.nearest(to: step),
                                   selected?.index != point.index {
                                    selected = point
                                }
                            }
                            .onEnded { _ in selected = nil })
                }
            }
        }
    }
}
