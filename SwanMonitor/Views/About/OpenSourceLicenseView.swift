//
//  OpenSourceLicenseView.swift
//  SwanMonitor
//
//  Created by aleclanned on 10/1/26.
//

import SwiftUI

struct OpenSourceLicenseView: View {
    var body: some View {
        List {
            Section {
                Link("Alamofire", destination: URL(string: "https://github.com/Alamofire/Alamofire/blob/master/LICENSE")!)
                Link("Nuke / NukeUI", destination: URL(string: "https://github.com/kean/Nuke/blob/main/LICENSE")!)
            }
        }
        .navigationTitle(String(localized: "开源许可"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    OpenSourceLicenseView()
}
