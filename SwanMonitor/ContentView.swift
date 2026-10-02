import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var sessions: [SessionModel]
    @Environment(AppLock.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if sessions.first?.isAuthenticated == true {
                MainView()
                    .disabled(appLock.isLocked)
                    .accessibilityHidden(appLock.isLocked)
                if appLock.isLocked {
                    PINView(unlocking: true)
                }
            } else {
                LandingPageView()
            }
            // 同时遮住后台快照，避免切换应用时暴露页面内容。
            if scenePhase != .active {
                Color(.systemBackground).ignoresSafeArea()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { appLock.enteredBackground() }
            if phase == .active { appLock.becameActive() }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppLock())
        .modelContainer(for: [SessionModel.self, UserModel.self], inMemory: true)
}
