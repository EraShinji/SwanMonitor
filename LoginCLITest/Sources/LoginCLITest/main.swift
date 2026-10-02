import Foundation
import Alamofire

// 用法: swift run LoginCLITest <endpoint> <api>
// 示例: swift run LoginCLITest "https://httpbin.org/post" "my-api-key"

guard CommandLine.arguments.count == 3 else {
    print("用法: LoginCLITest <endpoint> <api>")
    exit(1)
}

let endpoint = CommandLine.arguments[1]
let api = CommandLine.arguments[2]

let parameters: [String: String] = [
    "authorization": api
]

print("POST \(endpoint)")
print("parameters: \(parameters)")

let semaphore = DispatchSemaphore(value: 0)

AF.request(endpoint, method: .post, parameters: parameters)
    .validate()
    .response(queue: .global()) { response in
        defer { semaphore.signal() }
        print("HTTP 状态码: \(response.response?.statusCode ?? -1)")
        switch response.result {
        case .success(let data):
            if let data = data, let body = String(data: data, encoding: .utf8) {
                print("响应体:\n\(body)")
            } else {
                print("响应体为空")
            }
        case .failure(let error):
            print("请求失败: \(error.localizedDescription)")
        }
    }

semaphore.wait()
