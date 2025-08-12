import HealthKit
import Foundation

@Observable
class HealthManager: NSObject {
    @ObservationIgnored private let healthStore = HKHealthStore()
    
    var sleepData: [SleepData] = []
    var statusMessage: String = ""
    var hasError: Bool = false
    
    private var samplesBySessionId: [String: [HKCategorySample]] = [:]
    
    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            updateStatus("HealthKit is not available on this device", isError: true)
            return
        }
        
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.updateStatus("Health permissions granted")
                } else {
                    self?.updateStatus("Failed to get health permissions: \(error?.localizedDescription ?? "Unknown error")", isError: true)
                }
            }
        }
    }
    
    func addSleepLog(bedtime: Date, sleepTime: Date?, wakeTime: Date, outOfBedTime: Date?, completion: @escaping (Bool) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            updateStatus("Failed to create sleep analysis type", isError: true)
            completion(false)
            return
        }
        
        var samplesToSave: [HKCategorySample] = []
        
        // 1. In Bed period (from bedtime to out of bed time or wake time)
        let inBedEnd = outOfBedTime ?? wakeTime
        let inBedSample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.inBed.rawValue,
            start: bedtime,
            end: inBedEnd
        )
        samplesToSave.append(inBedSample)
        
        // 2. Asleep period (from sleep time to wake time)
        let asleepStart = sleepTime ?? bedtime
        let asleepSample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: asleepStart,
            end: wakeTime
        )
        samplesToSave.append(asleepSample)
        
        // Save all samples
        healthStore.save(samplesToSave) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    let duration = wakeTime.timeIntervalSince(asleepStart)
                    let hours = Int(duration) / 3600
                    let minutes = Int(duration) % 3600 / 60
                    self?.updateStatus("Sleep log saved successfully! Duration: \(hours)h \(minutes)m")
                    completion(true)
                } else {
                    self?.updateStatus("Failed to save sleep log: \(error?.localizedDescription ?? "Unknown error")", isError: true)
                    completion(false)
                }
            }
        }
    }
    
    func loadSleepData() {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -14, to: endDate)! // Last 14 days
        
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
                self?.updateStatus("Loaded \(processedData.count) sleep log\(processedData.count == 1 ? "" : "s")")
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processSleepSamples(_ samples: [HKCategorySample]) -> [SleepData] {
        // Clear previous sample storage
        samplesBySessionId.removeAll()
        
        // Group samples into sleep sessions instead of by day
        var sleepSessions: [[HKCategorySample]] = []
        
        // Sort all samples by start date
        let sortedSamples = samples.sorted { $0.startDate < $1.startDate }
        
        // Group samples that are close together in time (within 2 hours)
        var currentSession: [HKCategorySample] = []
        var lastEndTime: Date?
        
        for sample in sortedSamples {
            let timeSinceLastSample = lastEndTime?.timeIntervalSince(sample.startDate) ?? 0
            
            // If more than 2 hours gap, start a new session
            if abs(timeSinceLastSample) > 2 * 3600 && !currentSession.isEmpty {
                sleepSessions.append(currentSession)
                currentSession = [sample]
            } else {
                currentSession.append(sample)
            }
            
            lastEndTime = sample.endDate
        }
        
        // Don't forget the last session
        if !currentSession.isEmpty {
            sleepSessions.append(currentSession)
        }
        
        // Convert each session to SleepData
        var result: [SleepData] = []
        
        for (index, sessionSamples) in sleepSessions.enumerated() {
            let inBedSamples = sessionSamples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
            let asleepSamples = sessionSamples.filter {
                $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }
            
            if !inBedSamples.isEmpty || !asleepSamples.isEmpty {
                let allSamples = inBedSamples + asleepSamples
                let earliestStart = allSamples.min(by: { $0.startDate < $1.startDate })?.startDate ?? Date()
                let latestEnd = allSamples.max(by: { $0.endDate < $1.endDate })?.endDate ?? Date()
                
                let totalSleepDuration = asleepSamples.reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                }
                
                let sessionId = "\(earliestStart.timeIntervalSince1970)-\(index)"
                
                // Store the samples for potential deletion
                samplesBySessionId[sessionId] = sessionSamples
                
                let sleepData = SleepData(
                    date: earliestStart, // Use actual sleep start time instead of day
                    bedtime: earliestStart,
                    wakeTime: latestEnd,
                    duration: totalSleepDuration,
                    sessionId: sessionId // Unique identifier
                )
                
                result.append(sleepData)
            }
        }
        
        return result.sorted { $0.date > $1.date }
    }
    
    private func updateStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.statusMessage == message {
                self.statusMessage = ""
                self.hasError = false
            }
        }
    }
    
    func deleteSleepSession(_ sleepData: SleepData) {
        guard let samplesToDelete = samplesBySessionId[sleepData.sessionId] else {
            updateStatus("Cannot find samples to delete", isError: true)
            return
        }
        
        updateStatus("Deleting sleep session...")
        
        healthStore.delete(samplesToDelete) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    // Remove from local storage
                    self?.samplesBySessionId.removeValue(forKey: sleepData.sessionId)
                    
                    // Remove from displayed data
                    self?.sleepData.removeAll { $0.sessionId == sleepData.sessionId }
                    
                    let duration = sleepData.formattedDuration
                    self?.updateStatus("Sleep session deleted (\(duration))")
                } else {
                    self?.updateStatus("Failed to delete sleep session: \(error?.localizedDescription ?? "Unknown error")", isError: true)
                }
            }
        }
    }
}
