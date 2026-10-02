//
//  LandingPageView.swift
//  SwanMonitor
//
//  Created by aleclanned on 9/30/26.
//

import SwiftUI

struct LandingPageView: View {
    var body: some View {
        NavigationStack{
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    Image("SwanMonitorIcon")
                        .resizable()
                        .frame(width: 100, height: 100)
                    Text("Swan Monitor")
                        .font(.largeTitle)
                        .fontDesign(.rounded)
                        .fontWeight(.regular)
                    Text("An open-source monitor for SwanLab")
                        .font(.headline)
                        .fontDesign(.default)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(spacing:20) {
                    NavigationLink{
                        LoginAPIView()
                    }label: {
                         LandingPageLoginItemSwanLabView()
                    }
                    .buttonStyle(.borderedProminent)
                    .glassEffect()
                    NavigationLink{
                        LoginSelfHostView()
                    }label: {
                        LandingPageLoginItemSelfAPIView()
                    }
                    .buttonStyle(.borderless)
                }.padding(30)
                Spacer()
            }
        }
    }
}

#Preview {
    LandingPageView()
}
