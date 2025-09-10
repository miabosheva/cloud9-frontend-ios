import HealthKit
import Foundation

enum HealthError: Error {
    case failedToCreateType
    case noSamplesFound
    case healthKitNotAvailable
    case invalidSampleType
    case saveFailed
    case sleepLogExists
    
    var localizedDescription: String {
        switch self {
        case .failedToCreateType:
            return "Failed to create HealthKit data type"
        case .noSamplesFound:
            return "No samples found"
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .invalidSampleType:
            return "Invalid sample type returned from HealthKit"
        case .saveFailed:
            return "Failed to save data to HealthKit"
        case .sleepLogExists:
            return "Sleep Log exists."
        }
    }
}

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
    
    func requestPermissions() async {
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
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func loadInitialData() async {
        await loadHeartRateData(for: .today)
        await loadSleepData()
        loadSleepSamplesForChart(filter: .thisWeek)
    }
}
