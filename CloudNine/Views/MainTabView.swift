import SwiftUI
import HealthKit

struct MainTabView: View {
    
    @State private var healthManager = HealthManager()
    @State private var watchConnector = WatchConnector()
    
    var body: some View {
        Group {
            TabView {
                HomeView(watchConnector: watchConnector)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                SleepLogView()
                    .tabItem {
                        Label("Sleep Log", systemImage: "moon.stars.fill")
                    }
            }
            .handleGlobalErrors()
            .environment(healthManager)
        }
    }
}
