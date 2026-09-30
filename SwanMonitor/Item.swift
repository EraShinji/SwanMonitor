//
//  Item.swift
//  SwanMonitor
//
//  Created by aleclanned on 9/30/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
