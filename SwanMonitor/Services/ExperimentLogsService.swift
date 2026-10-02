import Foundation
import Alamofire

func getExperimentLogs(endpoint: String, sid: String, projectID: String, run: Experiment,
                       epoch: Int, level: String) async throws -> ExperimentLogPage {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let experimentID = run.cuid, let createdAt = run.createdAt,
          let date = formatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt),
          let base = URL(string: endpoint), ["https", "http"].contains(base.scheme), base.host != nil else {
        throw URLError(.cannotParseResponse)
    }
    // SDK log_offset maps to HTTP epoch, not an offset query parameter.
    // https://github.com/SwanHubX/SwanLab/blob/main/swanlab/api/metric.py
    var parameters: [String: Any] = ["projectId": projectID, "experimentId": experimentID,
        "createdAt": Int(date.timeIntervalSince1970), "epoch": epoch, "size": 1000, "level": level]
    if let value = run.rootProId { parameters["rootProId"] = value }
    if let value = run.rootExpId { parameters["rootExpId"] = value }
    return try await AF.request(base.appendingPathComponent("api/house/metrics/log"), parameters: parameters,
        headers: ["Cookie": "sid=\(sid)", "X-SwanLab-SDK-Version": "0.10.1"])
        .validate(statusCode: 200..<300).serializingDecodable(ExperimentLogPage.self).value
}
