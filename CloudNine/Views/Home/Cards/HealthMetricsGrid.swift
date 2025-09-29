import SwiftUI

struct HealthMetricsGrid: View {
    let healthManager: HealthManager
    let watchConnector: WatchConnector
    @Binding var showingSleepDebtDetails: Bool
    @Binding var showingInfoAlert: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                RealTimeHeartRateCard(watchConnector: watchConnector, showingInfoAlert: $showingInfoAlert)
                
                if let sleepDebtResult = healthManager.sleepDeptResult {
                    SleepDebtCard(
                        sleepDebtResult: sleepDebtResult,
                        onTap: { showingSleepDebtDetails = true }
                    )
                }
                
                TemperatureCard()
                
                SleepQualityCard()
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    HealthMetricsGrid(
        healthManager: HealthManager(),
        watchConnector: WatchConnector(),
        showingSleepDebtDetails: .constant(false),
        showingInfoAlert: .constant(false)
    )
}
