//
//  UserInfoServices.swift
//  SwanMonitor
//
//  Created by aleclanned on 10/1/26.
//
import Foundation
import Alamofire

nonisolated struct ProfileResponse: Codable, Sendable {
    let bio: String?
    let url: String?
    let institution: String?
    let school: String?
    let email: String?
    let location: String?
    let telephone: String?
    let phone: String?
}

nonisolated struct ProjectListResponse: Codable, Sendable {
    let total: Int
    let list: [Project]
    
    struct Project: Codable, Sendable {
        let name: String
        let path: String
        let user: ProjectUser
        
        struct ProjectUser: Codable, Sendable {
            let name: String
            let username: String
            let avatar: String?
            let status: String?
        }
    }
}

struct UserInfo {
    let username: String
    let email: String?
    let institution: String?
    let phone: String?
    let avatarUrl: String?
}

func getUserInfo(endpoint: String, sid: String,username:String) async -> UserInfo? {
    let headers: HTTPHeaders = [
        "Cookie": "sid=\(sid)"
    ]
    let base = endpoint.hasSuffix("/") ? String(endpoint.dropLast()) : endpoint
    
    let profileResponse = await AF.request(
        base + "/api/user/profile",
        method: .get,
        headers: headers
    )
    .serializingDecodable(ProfileResponse.self)
    .response
    
    guard profileResponse.response?.statusCode == 200,
          let profile = try? profileResponse.result.get() else {
        print("获取用户资料失败")
        return nil
    }
    
    let projectResponse = await AF.request(
        base + "/api/project/" + username,
        method: .get,
        headers: headers
    )
    .serializingDecodable(ProjectListResponse.self)
    .response
    
    let projects = projectResponse.response?.statusCode == 200
        ? try? projectResponse.result.get() : nil
    let avatarUrl = projects?.list.first?.user.avatar
    
    return UserInfo(
        username: username,
        email: profile.email,
        institution: profile.institution,
        phone: profile.phone,
        avatarUrl: avatarUrl
    )
}

// 自部署返回根相对路径，云端可能返回完整 CDN 地址。
func resolvedAvatarURL(_ value: String?, endpoint: String) -> URL? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let base = URL(string: endpoint.hasSuffix("/") ? endpoint : endpoint + "/"),
          let url = URL(string: value, relativeTo: base)?.absoluteURL,
          ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
          url.host != nil else { return nil }
    return url
}
