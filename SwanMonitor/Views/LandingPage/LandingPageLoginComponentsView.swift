//
//  LandingPageLoginItemView.swift
//  SwanMonitor
//
//  Created by aleclanned on 10/2/26.
//

import SwiftUI

struct LandingPageLoginItemSwanLabView: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Log in with").font(.subheadline)
            Image("logo_swanlab")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .baselineOffset(10)
                .frame(height: 20)
            Text(" API").font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: 40)
    }
}

struct LandingPageLoginItemSelfAPIView: View {
    var body: some View {
        Text("Log in with Self Host SwanLab")
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth:.infinity,maxHeight: 40)
    }
}
