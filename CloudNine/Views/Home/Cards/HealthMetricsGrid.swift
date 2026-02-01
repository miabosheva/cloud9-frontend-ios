import SwiftUI

struct HealthMetricsGrid: View {
    @Environment(HealthManager.self) var healthManager
    let watchConnector: WatchConnectivityManager
    @Binding var showingSleepDebtDetails: Bool
    @Binding var showingInfoAlert: Bool
    
    var sleepFromLastNight: [SleepData] {
        let calendar = Calendar.current
        let today = Date.now
        
        return healthManager.sleepData.filter { data in
            calendar.isDate(data.wakeTime, inSameDayAs: today)
        }
    }
    
    var duration: String? {
        return sleepFromLastNight.totalFormattedDuration
    }
    
    var quality: String? {
        return sleepFromLastNight.medianQuality?.rawValue
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                // Stress prediction card at the top
                StressPredictionCard(watchConnector: watchConnector)
                
                RealTimeHeartRateCard(watchConnector: watchConnector, showingInfoAlert: $showingInfoAlert)
                
                if let sleepDebtResult = healthManager.sleepDebtResult {
                    SleepDebtCard(
                        sleepDebtResult: sleepDebtResult,
                        onTap: { showingSleepDebtDetails = true }
                    )
                }
                
                SleepQualityCard(duration: duration, quality: quality)
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    HealthMetricsGrid(
        watchConnector: WatchConnectivityManager(),
        showingSleepDebtDetails: .constant(false),
        showingInfoAlert: .constant(false)
    )
    .environment(HealthManager())
}
