import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    
    var healthStore: HKHealthStore?
    var isHealthDataAvailable: Bool = false
    var heartRateQuery: HKObserverQuery?
    
    /// MARK: - Authorized for now
    @Published var authorizationStatus: AuthorizationStatus = .authorized
    @Published var latestHeartRate: Double?
    
    let requiredReadTypes: Set<HKObjectType> = [
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
        HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
    ]
    
    init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HKHealthStore()
            self.isHealthDataAvailable = true
        } else {
            self.healthStore = nil
            self.isHealthDataAvailable = false
            print("Health data is not available on this device.")
        }
    }
}
