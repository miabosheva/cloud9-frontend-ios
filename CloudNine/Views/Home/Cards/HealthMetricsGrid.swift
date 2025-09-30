import SwiftUI

struct HealthMetricsGrid: View {
    let healthManager: HealthManager
    let watchConnector: WatchConnector
    @Binding var showingSleepDebtDetails: Bool
    @Binding var showingInfoAlert: Bool
    
    var sleepFromToday: [SleepData] {
        let calendar = Calendar.current
        let day = Date.now
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        
        return healthManager.sleepData.filter { data in
            calendar.isDate(data.date, inSameDayAs: yesterday)
        }
    }
    
    var duration: String? {
        return sleepFromToday.totalFormattedDuration
    }
    
    var quality: String? {
        return sleepFromToday.medianQuality?.rawValue
    }
    
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
                
                SleepQualityCard(duration: duration, quality: quality)
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
