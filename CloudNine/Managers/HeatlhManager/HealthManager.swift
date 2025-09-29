import HealthKit
import Foundation

@MainActor
@Observable
class HealthManager: NSObject {
    
    @ObservationIgnored let healthStore = HKHealthStore()
    @ObservationIgnored var firebaseManager = FirebaseManager()
    
    var sleepChartData: [SleepChartData] = []
    var heartRateData: [HeartRateData] = []
    var sleepData: [SleepData] = []
    var sleepDeptResult: AutomatedSleepDebtResult?
    var error: Error?
    
    var samplesBySessionId: [String: [HKCategorySample]] = [:]
    var userPerssistanceService: UserPerssistanceServiceProtocol = UserPersistenceService()
    
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
    
    func calculateSleepDept(user: UserInfo) {
        var settings = AutomatedSleepDebtCalculator.AutomationSettings()
        settings.primaryGoal = user.trackingGoal
        settings.adaptiveStrategy = true
        settings.dataQualityThreshold = 0.7

        let automatedCalculator = AutomatedSleepDebtCalculator(
            recommendedSleepHours: user.sleepDuration,
            settings: settings
        )

        // One-line automated calculation
        let result = automatedCalculator.automaticCalculateDebt(sleepData: sleepData)
        self.sleepDeptResult = result
    }
}
