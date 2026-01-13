import HealthKit
import Foundation

@MainActor
@Observable
class HealthManager: NSObject {
    
    enum AuthorizationStatus {
        case unknown
        case granted
        case denied
    }
    
    @ObservationIgnored let healthStore = HKHealthStore()
    @ObservationIgnored var firebaseManager = FirebaseManager()
    
    var sleepChartData: [SleepChartData] = []
    var heartRateData: [HeartRateData] = []
    var sleepData: [SleepData] = []
    var sleepDebtResult: AutomatedSleepDebtResult?
    var error: Error?
    
    var samplesBySessionId: [String: [HKCategorySample]] = [:]
    var userPersistenceService: UserPersistenceServiceProtocol = UserPersistenceService()
    
    var authorizationStatus: AuthorizationStatus = .unknown
    
    func requestPermissions() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .denied
            return
        }
        
        guard let sleepAnalysisType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let bodyTemperatureType = HKObjectType.quantityType(forIdentifier: .bodyTemperature) else {
            await MainActor.run {
                self.authorizationStatus = .denied
                self.error = HealthError.failedToCreateType
            }
            return
        }
        
        let typesToShare: Set<HKSampleType> = [sleepAnalysisType]
        let typesToRead: Set<HKObjectType> = [sleepAnalysisType, heartRateType, bodyTemperatureType]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            
            let status = healthStore.authorizationStatus(for: sleepAnalysisType)
            
            await MainActor.run {
                if status == .sharingAuthorized {
                    self.authorizationStatus = .granted
                } else {
                    self.authorizationStatus = .denied
                }
            }
        } catch {
            await MainActor.run {
                self.authorizationStatus = .denied
                self.error = error
            }
        }
    }
    
    func loadInitialData() async throws {
        try await loadHeartRateData(for: .thisMonth)
        try await loadSleepData()
        loadSleepSamplesForChart(filter: .thisWeek)
    }
    
    func calculateSleepDebt(user: UserInfo) {
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
        self.sleepDebtResult = result
    }
}
