import SwiftUI
import HealthKit

struct HomeView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var errorMessage: String?
    @State private var showingAuthorizationSheet = true
    
    var body: some View {
        VStack {
            if let heartRate = healthKitManager.latestHeartRate {
                Text("Heart Rate: \(heartRate)")
            } else {
                Text("Heart Rate: N/A")
            }
            
        }
    }
}
