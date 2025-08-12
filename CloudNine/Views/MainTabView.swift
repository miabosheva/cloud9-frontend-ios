import SwiftUI
import HealthKit

struct MainTabView: View {
    
    @Bindable private var healthManager = HealthManager()
    @Bindable private var watchConnector = WatchConnector()
    
    var body: some View {
        Group {
            TabView {
                HomeView(healthManager: healthManager, watchConnector: watchConnector)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                SleepLogView(healthManager: healthManager)
                    .tabItem {
                        Label("Sleep Log", systemImage: "moon.stars.fill")
                    }
            }
        }
    }
}
