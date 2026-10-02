//
//  SoftwareInformationView.swift
//  SwanMonitor
//
//  Created by aleclanned on 10/1/26.
//

import SwiftUI

struct SoftwareInformationView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
    var body: some View {
        
        List {
            Section {
                LabeledContent(String(localized: "应用"), value: "SwanMonitor")
                LabeledContent(String(localized: "版本"), value: version)
                LabeledContent(String(localized: "构建号"), value: build)
            }
        }
        .navigationTitle(String(localized: "版本信息"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SoftwareInformationView()
}
