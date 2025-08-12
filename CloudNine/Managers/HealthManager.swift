import HealthKit
import Foundation

class HealthManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var sleepData: [SleepData] = []
    @Published var statusMessage: String = ""
    @Published var hasError: Bool = false
    
    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            updateStatus("HealthKit is not available on this device", isError: true)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.updateStatus("Health permissions granted")
                } else {
                    self?.updateStatus("Failed to get health permissions: \(error?.localizedDescription ?? "Unknown error")", isError: true)
                }
            }
        }
    }
    
    func loadSleepData() {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] query, samples, error in
            
            if let error = error {
                DispatchQueue.main.async {
                    self?.updateStatus("Failed to load sleep data: \(error.localizedDescription)", isError: true)
                }
                return
            }
            
            guard let sleepSamples = samples as? [HKCategorySample] else {
                DispatchQueue.main.async {
                    self?.updateStatus("No sleep data found")
                }
                return
            }
            
            let processedData = self?.processSleepSamples(sleepSamples) ?? []
            
            DispatchQueue.main.async {
                self?.sleepData = processedData
                self?.updateStatus("Sleep data loaded (\(processedData.count) days)")
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processSleepSamples(_ samples: [HKCategorySample]) -> [SleepData] {
        let calendar = Calendar.current
        var sleepByDay: [String: [HKCategorySample]] = [:]
        
        // Group sleep samples by day
        for sample in samples {
            let dayKey = calendar.startOfDay(for: sample.startDate)
            let dayString = ISO8601DateFormatter().string(from: dayKey)
            
            if sleepByDay[dayString] == nil {
                sleepByDay[dayString] = []
            }
            sleepByDay[dayString]?.append(sample)
        }
        
        // Process each day's sleep data
        var result: [SleepData] = []
        
        for (dayString, samples) in sleepByDay {
            guard let dayDate = ISO8601DateFormatter().date(from: dayString) else { continue }
            
            let inBedSamples = samples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
            let asleepSamples = samples.filter {
                $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }
            
            if !inBedSamples.isEmpty || !asleepSamples.isEmpty {
                let allSamples = inBedSamples + asleepSamples
                let earliestStart = allSamples.min(by: { $0.startDate < $1.startDate })?.startDate ?? dayDate
                let latestEnd = allSamples.max(by: { $0.endDate < $1.endDate })?.endDate ?? dayDate
                
                let totalSleepDuration = asleepSamples.reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                }
                
                let sleepData = SleepData(
                    date: dayDate,
                    bedtime: earliestStart,
                    wakeTime: latestEnd,
                    duration: totalSleepDuration
                )
                
                result.append(sleepData)
            }
        }
        
        return result.sorted { $0.date > $1.date }
    }
    
    private func updateStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
        
        // Clear status message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.statusMessage = ""
            self.hasError = false
        }
    }
}
