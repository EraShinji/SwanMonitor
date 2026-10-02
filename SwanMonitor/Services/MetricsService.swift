import Foundation
import Alamofire

nonisolated struct MetricKeys: Decodable, Sendable {
    let keys: [String]
    let hasMore: Bool
    let nextCursor: String?
}

func metricsRequest<T: Decodable & Sendable>(endpoint: String, route: String, sid: String, body: [String: Any]) async throws -> T {
    guard let base = URL(string: endpoint), let scheme = base.scheme,
          ["http", "https"].contains(scheme), base.host != nil else { throw URLError(.badURL) }
    return try await AF.request(base.appendingPathComponent("api/house/metrics/" + route), method: .post,
                               parameters: body, encoding: JSONEncoding.default, headers: ["Cookie": "sid=\(sid)"])
        .validate(statusCode: 200..<300).serializingDecodable(T.self).value
}

nonisolated struct MetricExport: Decodable, Sendable { let cosKey: String }
nonisolated struct MetricDownload: Decodable, Sendable { let urls: [String] }

// 导出 CSV 不受 scalar 的 num 采样上限约束；下载时不向对象存储发送会话 Cookie。
func fullMetricSeries(endpoint: String, sid: String, projectID: String, columns: [[String: Any]]) async throws -> [MetricSeries] {
    let export: MetricExport = try await metricsRequest(endpoint: endpoint, route: "scalar/export", sid: sid,
        body: ["projectId": projectID, "columns": columns])
    guard let base = URL(string: endpoint) else { throw URLError(.badURL) }
    let signed = try await AF.request(base.appendingPathComponent("api/files/presigned/get"), method: .post,
        parameters: ["paths": [export.cosKey]], encoding: JSONEncoding.default, headers: ["Cookie": "sid=\(sid)"])
        .validate(statusCode: 200..<300).serializingDecodable(MetricDownload.self).value
    guard let value = signed.urls.first, let url = URL(string: value),
          ["https", "http"].contains(url.scheme ?? "") else { throw URLError(.badURL) }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let (data, response) = try await session.data(from: url)
    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
        throw URLError(.cannotParseResponse)
    }
    let descriptors = try columns.map { column -> MetricCSVColumn in
        guard let key = column["key"] as? String, let name = column["experimentName"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        return MetricCSVColumn(key: key, experimentName: name)
    }
    return try await decodeMetricData(data, columns: descriptors)
}

