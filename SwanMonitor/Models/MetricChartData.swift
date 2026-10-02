import Foundation

// Immutable, shared by the card and full-screen view. Every valid source sample
// keeps its original step, value and timestamp; no resampling or smoothing.
nonisolated struct MetricChartSample: Sendable {
    let index: Double
    let value: Double
    let timestamp: Double?
}

nonisolated struct MetricChartData: Sendable, Identifiable {
    let id = UUID()
    let points: [MetricChartSample]
    let bounds: ClosedRange<Double>
    var isEmpty: Bool { points.isEmpty }

    // The CSV decoder already supplies unique, ascending steps.
    init(sortedPoints: [MetricPoint]) {
        var samples: [MetricChartSample] = []
        samples.reserveCapacity(sortedPoints.count)
        var low = Double.infinity
        var high = -Double.infinity
        for point in sortedPoints {
            guard point.index.isFinite, let value = point.data, value.isFinite else { continue }
            samples.append(MetricChartSample(index: point.index, value: value, timestamp: point.timestamp))
            low = min(low, value)
            high = max(high, value)
        }
        points = samples
        if samples.isEmpty { low = 0; high = 1 }
        let margin = max((high - low) * 0.08, max(abs(high) * 0.01, 0.000001))
        let lower = low - margin
        let upper = high + margin
        bounds = (lower.isFinite ? lower : low)...(upper.isFinite ? upper : high)
    }

    func nearest(to step: Double) -> MetricChartSample? {
        guard !points.isEmpty, step.isFinite else { return nil }
        var lower = 0
        var upper = points.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if points[middle].index < step { lower = middle + 1 } else { upper = middle }
        }
        if lower == 0 { return points[0] }
        if lower == points.count { return points[lower - 1] }
        return step - points[lower - 1].index <= points[lower].index - step ? points[lower - 1] : points[lower]
    }
}

@concurrent
nonisolated func prepareMetricCharts(_ series: [MetricSeries]) async throws -> [String: MetricChartData] {
    var result: [String: MetricChartData] = [:]
    for item in series {
        try Task.checkCancellation()
        result[item.key] = MetricChartData(sortedPoints: item.metrics)
    }
    return result
}
