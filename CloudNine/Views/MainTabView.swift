import SwiftUI
import HealthKit

struct MainTabView: View {
    @State private var healthManager = HealthManager()
    @State private var watchConnector = WatchConnectivityManager()
    @StateObject private var stressPromptManager: StressPromptManager
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var notificationHandler = NotificationHandler.shared
    
    init() {
        _stressPromptManager = StateObject(wrappedValue: StressPromptManager(watchConnector: WatchConnectivityManager()))
    }
    
    var body: some View {
        Group {
            switch healthManager.authorizationStatus {
            case .unknown:
                ProgressView("Checking Health permissions...")
                    .task {
                        await healthManager.requestPermissions()
                    }
                
            case .denied:
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    Text("Health Access Required")
                        .font(.headline)
                    Text("This app needs access to your Health data to function properly. Please enable permissions in Settings → Health.")
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .padding()
                
            case .granted:
                Group {
                    if #available(iOS 26, *) {
                        TabView {
                            HomeView(watchConnector: watchConnector)
                                .tabItem {
                                    Label("Home", systemImage: "house.fill")
                                }
                            
                            SleepSummaryTabs()
                                .tabItem {
                                    Label("Sleep Log", systemImage: "moon.stars.fill")
                                }
                        }
                        .tint(.accentColor)
                    } else {
                        TabView {
                            HomeView(watchConnector: watchConnector)
                                .tabItem {
                                    Label("Home", systemImage: "house.fill")
                                }
                            
                            SleepSummaryTabs()
                                .tabItem {
                                    Label("Sleep Log", systemImage: "moon.stars.fill")
                                }
                        }
                    }
                }
                .handleGlobalErrors()
                .environment(healthManager)
                .environmentObject(stressPromptManager)
                .onChange(of: notificationHandler.didTapStressPrompt) { _, newValue in
                    if newValue {
                        stressPromptManager.beginMeasurement(isTest: false)
                        notificationHandler.didTapStressPrompt = false
                    }
                }
            }
        }
    }
}
