import Foundation

// Run with swiftc -parse-as-library, alongside MetricDataProcessing.swift and MetricChartData.swift.
@main
struct MetricPerformanceChecks {
    @MainActor static var ticks = 0

    @MainActor
    static func main() async throws {
        let column = MetricCSVColumn(key: "loss", experimentName: "run")
        let count = 100_000
        var csv = "step,run-loss_step,run-loss_timestamp\n"
        // Descending steps, fractional steps, negative values and isolated spikes.
        for i in (0..<count).reversed() {
            let value = i == 50001 ? 123456.789 : sin(Double(i)) * 10
            csv += "\(Double(i) * 0.25),\(value),\(1700000000.0 + Double(i))\n"
        }
        let bytes = Data(csv.utf8)
        let heartbeat = Task { @MainActor in
            while !Task.isCancelled {
                ticks += 1
                try? await Task.sleep(for: .milliseconds(5))
            }
        }
        await Task.yield()
        let before = ticks
        let start = ContinuousClock.now
        let series = try await decodeMetricData(bytes, columns: [column])
        let charts = try await prepareMetricCharts(series)
        let duration = start.duration(to: .now)
        heartbeat.cancel()
        precondition(ticks > before, "MainActor could not run during decoding")
        let chart = charts["loss"]!
        precondition(chart.points.count == count)
        for i in 0..<count {
            let point = chart.points[i]
            let expected = i == 50001 ? 123456.789 : sin(Double(i)) * 10
            precondition(point.index == Double(i) * 0.25)
            precondition(point.value.bitPattern == expected.bitPattern, "Changed source value")
            precondition(point.timestamp == 1700000000.0 + Double(i))
            precondition(chart.bounds.contains(point.value))
        }
        for target in stride(from: -1.0, through: 25001.0, by: 251.375) {
            let reference = chart.points.min { abs($0.index - target) < abs($1.index - target) }!
            precondition(chart.nearest(to: target)?.index == reference.index)
        }
        precondition(chart.nearest(to: .nan) == nil)
        let empty = MetricChartData(sortedPoints: [])
        precondition(empty.nearest(to: 0) == nil && empty.bounds.lowerBound.isFinite)
        let single = MetricChartData(sortedPoints: [MetricPoint(index: 0.125, data: -7, timestamp: nil)])
        precondition(single.nearest(to: 100)?.value == -7 && single.bounds.contains(-7))
        let constant = MetricChartData(sortedPoints: (0..<10).map { MetricPoint(index: Double($0), data: 0, timestamp: nil) })
        precondition(constant.bounds.lowerBound < 0 && constant.bounds.upperBound > 0)
        // Preserve existing CSV behavior: quoted names, CRLF, sparse columns,
        // final duplicate-step value, timestamps and missing values.
        let quoted = "step,\"a,\"\"b-loss_step\",\"a,\"\"b-loss_timestamp\"\r\n2,3,20\r\n1,,10\r\n2,4,21\r\n0,-2,0"
        let decoded = try await decodeMetricData(Data(quoted.utf8), columns: [.init(key: "loss", experimentName: "a,\"b")])
        precondition(decoded[0].metrics.map(\.index) == [0, 2])
        precondition(decoded[0].metrics.map(\.data) == [-2, 4])
        precondition(decoded[0].metrics.last?.timestamp == 21)
        do {
            _ = try await decodeMetricData(Data("step,\"unterminated".utf8), columns: [column])
            preconditionFailure("Malformed CSV accepted")
        } catch { }
        let cancelled = Task { try await decodeMetricData(bytes, columns: [column]) }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            preconditionFailure("Cancelled decoding completed")
        } catch is CancellationError { }
        print("PASS: 100,000 exact values/steps/timestamps, spike, negative and constant series, nearest lookup, CSV edge cases, cancellation")
        print("Background decode + preparation: \(duration); MainActor heartbeat ticks: \(ticks - before)")
    }
}
