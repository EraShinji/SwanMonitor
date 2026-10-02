import Foundation
import Alamofire

nonisolated struct ExperimentList: Decodable, Sendable {
    let total: Int
    let pages: Int
    let list: [Experiment]
}

nonisolated struct Experiment: Decodable, Sendable, Identifiable {
    var id: String { slug }
    let cuid: String?
    let rootProId: String?
    let rootExpId: String?
    let slug: String
    let name: String
    let state: String
    let description: String?
    let createdAt: String?
    let finishedAt: String?
    let profile: Profile?

    struct Profile: Decodable, Sendable {
        let config: [String: Parameter]?
        let requirements: String?
    }
    struct Parameter: Decodable, Sendable {
        let sort: Int?
        let value: JSONValue
    }
}

// 参数值可能是标量、数组或对象；保留类型，避免一个复杂参数导致整个实验解码失败。
nonisolated enum JSONValue: Codable, Sendable {
    case string(String), number(Double), bool(Bool), array([JSONValue]), object([String: JSONValue]), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    var text: String {
        if case .string(let value) = self { return value }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? String(decoding: encoder.encode(self), as: UTF8.self)) ?? "—"
    }
}

func projectRequest<T: Decodable & Sendable>(endpoint: String, path: String, sid: String, parameters: [String: Int] = [:]) async throws -> T {
    guard let base = URL(string: endpoint), let scheme = base.scheme,
          ["http", "https"].contains(scheme), base.host != nil else { throw URLError(.badURL) }
    let url = path.split(separator: "/").reduce(base.appendingPathComponent("api/project")) {
        $0.appendingPathComponent(String($1))
    }
    return try await AF.request(url, parameters: parameters, headers: ["Cookie": "sid=\(sid)"])
        .validate(statusCode: 200..<300)
        .serializingDecodable(T.self).value
}

// 汇总状态时必须读取所有页，避免遗漏后续页的运行中或中止实验。
func getAllExperiments(endpoint: String, path: String, sid: String) async throws -> [Experiment] {
    var response: ExperimentList = try await projectRequest(endpoint: endpoint, path: path + "/runs", sid: sid)
    var all = response.list
    if response.pages > 1 {
        for page in 2...response.pages {
            try Task.checkCancellation()
            response = try await projectRequest(endpoint: endpoint, path: path + "/runs", sid: sid, parameters: ["page": page])
            let known = Set(all.map(\.id))
            let next = response.list.filter { !known.contains($0.id) }
            guard !next.isEmpty else { throw URLError(.cannotParseResponse) }
            all.append(contentsOf: next)
        }
    }
    guard all.count >= response.total else { throw URLError(.cannotParseResponse) }
    return all
}
