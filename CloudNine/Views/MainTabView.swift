import SwiftUI
import HealthKit

struct MainTabView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager

    var body: some View {
        Group {
            switch healthKitManager.authorizationStatus {
            case .authorized:
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
                .onAppear {
                    healthKitManager.setupDataObservationAndFetch()
                }

            case .requiredPermissionsMissing:
                AuthorizationErrorView(
                    description: "To use all features of CloudNine, please grant access to your Health data in the Health App."
                )

            case .notAvailableOnDevice, .unknown:
                ErrorView(description: "This device does not support HealthKit.")
            }
        }
    }
}
