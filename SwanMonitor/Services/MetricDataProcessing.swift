import Foundation

nonisolated struct MetricSeries: Decodable, Sendable {
    let key: String
    let metrics: [MetricPoint]
}
nonisolated struct MetricPoint: Decodable, Sendable, Identifiable {
    var id: Double { index }
    let index: Double
    let data: Double?
    let timestamp: Double?
}

nonisolated struct MetricCSVColumn: Sendable {
    let key: String
    let experimentName: String
}

// Explicitly leave the caller's actor, including under default MainActor isolation.
@concurrent
nonisolated func decodeMetricData(_ data: Data, columns: [MetricCSVColumn]) async throws -> [MetricSeries] {
    try Task.checkCancellation()
    guard let csv = String(data: data, encoding: .utf8) else { throw URLError(.cannotParseResponse) }
    let result = try decodeMetricCSV(csv, columns: columns.map {
        ["key": $0.key, "experimentName": $0.experimentName]
    })
    try Task.checkCancellation()
    return result
}

nonisolated func decodeMetricCSV(_ csv: String, columns: [[String: Any]]) throws -> [MetricSeries] {
    // 处理带逗号、双引号或换行的实验名称。
    var rows: [[String]] = []
    var row: [String] = []
    var field = ""
    var quoted = false
    let chars = Array(csv)
    var i = 0
    while i < chars.count {
        if i % 16384 == 0 { try Task.checkCancellation() }
        let c = chars[i]
        if c == "\"" {
            if quoted && i + 1 < chars.count && chars[i + 1] == "\"" { field.append(c); i += 1 }
            else { quoted.toggle() }
        } else if c == "," && !quoted { row.append(field); field = "" }
        else if (c == "\n" || c == "\r\n") && !quoted {
            row.append(field.trimmingCharacters(in: .newlines)); rows.append(row); row = []; field = ""
        } else { field.append(c) }
        i += 1
    }
    guard !quoted else { throw URLError(.cannotParseResponse) }
    if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
    guard let header = rows.first, let stepIndex = header.firstIndex(of: "step") else { throw URLError(.cannotParseResponse) }
    return try columns.map { column in
        guard let key = column["key"] as? String, let name = column["experimentName"] as? String,
              let valueIndex = header.firstIndex(of: name + "-" + key + "_step") else { throw URLError(.cannotParseResponse) }
        let timeIndex = header.firstIndex(of: name + "-" + key + "_timestamp")
        var points: [Double: MetricPoint] = [:]
        for (index, row) in rows.dropFirst().enumerated() {
            if index % 4096 == 0 { try Task.checkCancellation() }
            guard row.count > max(stepIndex, valueIndex), let step = Double(row[stepIndex]), step.isFinite,
                  let value = Double(row[valueIndex]), value.isFinite else { continue }
            let time = timeIndex.flatMap { $0 < row.count ? Double(row[$0]) : nil }
            points[step] = MetricPoint(index: step, data: value, timestamp: time)
        }
        return MetricSeries(key: key, metrics: points.values.sorted { $0.index < $1.index })
    }
}
