//
//  SessionModel.swift
//  SwanMonitor
//
//  Created by aleclanned on 9/30/26.
//

import Foundation
import SwiftData

@Model
final class SessionModel{
    var isAuthenticated:Bool
    var hostUrl:String?
    var expiredTime:Date?
    init(isAuthenticated:Bool=false,hostUrl:String? = nil,expiredTime:Date? = nil){
        self.isAuthenticated = isAuthenticated
        self.hostUrl = hostUrl
        self.expiredTime = expiredTime
    }
    
}
