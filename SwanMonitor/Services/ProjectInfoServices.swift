import Foundation
import Alamofire

nonisolated struct ProjectInfoListResponse: Decodable, Sendable {
    let total: Int
    let list: [Project]

    struct Project: Decodable, Sendable, Identifiable {
        var id: String { path }
        let cuid: String?
        let name: String
        let path: String
        let description: String?
        let archived: Bool?
        let createdAt: String?
        let visibility: String?
        let _count: Counts?

        struct Counts: Decodable, Sendable {
            let experiments: Int?
            let runningExps: Int?
        }
    }
}

func getProjects(endpoint: String, sid: String, username: String, page: Int = 1) async throws -> ProjectInfoListResponse {
    guard let base = URL(string: endpoint),
          let scheme = base.scheme, ["http", "https"].contains(scheme), base.host != nil else {
        throw URLError(.badURL)
    }
    let url = base
        .appendingPathComponent("api")
        .appendingPathComponent("project")
        .appendingPathComponent(username)
    return try await AF.request(url, parameters: ["page": page], headers: ["Cookie": "sid=\(sid)"])
        .validate(statusCode: 200..<300)
        .serializingDecodable(ProjectInfoListResponse.self)
        .value
}
