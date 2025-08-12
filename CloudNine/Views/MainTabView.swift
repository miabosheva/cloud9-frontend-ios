import SwiftUI
import HealthKit

struct MainTabView: View {
    var body: some View {
        Group {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                SleepLogView()
                    .tabItem {
                        Label("Sleep Log", systemImage: "moon.stars.fill")
                    }
            }
        }
    }
}
