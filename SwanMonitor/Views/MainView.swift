//
//  MainView.swift
//  SwanMonitor
//
//  Created by aleclanned on 9/30/26.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @State var selection:Int = 0
    var body: some View{
        TabView(selection: $selection){
            Tab("Home",systemImage: "house",value: 0){
                HomeView()
            }
            
            Tab("Browse",systemImage: "safari",value: 1){
                BrowseView()
            }
            Tab("Profiles",systemImage: "person",value: 2){
                UserProfileView()
                
            }
            
        }
    }
}

#Preview {
    MainView()
        .environment(AppLock())
        .modelContainer(for: [UserModel.self, SessionModel.self], inMemory: true)
}
