//
//  UserModel.swift
//  SwanMonitor
//
//  Created by aleclanned on 10/1/26.
//

import Foundation
import SwiftData
@Model
class UserModel{
    var userName:String?
    var name:String?
    var avatarUrl:String?
    var institution:String?
    var email:String?
    init(userName: String? = nil, name: String? = nil, avatarUrl: String? = nil, institution: String? = nil, email: String? = nil) {
        self.userName = userName
        self.name = name
        self.avatarUrl = avatarUrl
        self.institution = institution
        self.email = email
    }
}
