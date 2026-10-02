//
//  SwanMonitorApp.swift
//  SwanMonitor
//
//  Created by aleclanned on 9/30/26.
//

import SwiftUI
import SwiftData

@main
struct SwanMonitorApp: App {
    @State private var appLock = AppLock()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appLock)
        }.modelContainer(for: [SessionModel.self, UserModel.self])
    }
}
