//
//  LoginServices.swift
//  SwanMonitor
//
//  Created by aleclanned on 9/30/26.
//

import Foundation
import Alamofire

nonisolated struct LoginResponse: Codable, Sendable {
    let sid: String
    let expiredAt: String
    let userInfo: UserInfo
    
    struct UserInfo: Codable, Sendable {
        let username: String
        let name: String
        let avatar: String
    }
}

func login(endpoint: String, api: String) async -> LoginResponse? {
    let requestAddr = if endpoint.hasSuffix("/") {
        endpoint + "api/login/api_key"
    } else {
        endpoint + "/api/login/api_key"
    }
    let headers: HTTPHeaders = ["authorization": api]
    
    let response = await AF.request(requestAddr, method: .post, headers: headers)
        .serializingDecodable(LoginResponse.self)
        .response
    
    guard response.response?.statusCode == 200 else { return nil }
    return try? response.result.get()
}
