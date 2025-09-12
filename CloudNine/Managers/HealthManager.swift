import HealthKit
import Foundation

@MainActor
@Observable
class HealthManager: NSObject {
    
    @ObservationIgnored let healthStore = HKHealthStore()
    
    var sleepChartData: [SleepChartData] = []
    var heartRateData: [HeartRateData] = []
    var sleepData: [SleepData] = []
    var userInfo = UserInfo()
    var error: Error?
    
    var samplesBySessionId: [String: [HKCategorySample]] = [:]
    
    func requestPermissions() async throws {
        do {
            guard HKHealthStore.isHealthDataAvailable() else {
                await MainActor.run {
                    self.error = HealthError.healthKitNotAvailable
                }
                return
            }
            
            let typesToShare: Set<HKSampleType> = [
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            ]
            
            let typesToRead: Set<HKObjectType> = [
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .bodyTemperature)!
            ]
            
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            print("Health permissions granted")
        } catch {
            throw error
        }
    }
    
    func loadInitialData() async throws {
        try await loadHeartRateData(for: .today)
        try await loadSleepData()
        loadSleepSamplesForChart(filter: .thisWeek)
    }
}
