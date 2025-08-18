import HealthKit
import Foundation

enum HealthError: Error {
    case failedToCreateType
    case noSamplesFound
    case healthKitNotAvailable
    case invalidSampleType
    case saveFailed
    
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
        }
    }
}

@Observable
class HealthManager: NSObject {
    @ObservationIgnored private let healthStore = HKHealthStore()
    
    var sleepChartData: [SleepChartData] = []
    var heartRateChartData: [HeartRateData] = []
    var sleepData: [SleepData] = []
    var error: Error?
    
    private var samplesBySessionId: [String: [HKCategorySample]] = [:]
    
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
        await loadSleepChartData(for: .today)
        await loadSleepData()
    }
    
    // MARK: - Heart Rate Data Loading
    
    func loadHeartRateData(for filter: TimeFilter) async {
        do {
            let heartRateSamples = try await fetchHeartRateSamples(for: filter)
            let data = heartRateSamples.map { sample in
                HeartRateData(
                    date: sample.startDate,
                    heartRate: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())),
                    timestamp: formatTimestamp(sample.startDate, for: filter)
                )
            }
            
            await MainActor.run {
                self.heartRateChartData = data.isEmpty ? generateMockHeartRateData(for: filter) : data
            }
        } catch {
            await MainActor.run {
                self.heartRateChartData = generateMockHeartRateData(for: filter)
                print("Failed to load heart rate data: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchHeartRateSamples(for filter: TimeFilter) async throws -> [HKQuantitySample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthError.failedToCreateType
        }
        
        let (startDate, endDate) = dateRange(for: filter)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let heartRateSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(throwing: HealthError.noSamplesFound)
                    return
                }
                
                continuation.resume(returning: heartRateSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Sleep Data Loading (for list view)
    
    func loadSleepData() async {
        do {
            let sleepSamples = try await fetchSleepSamples(last30Days: true)
            let processedData = processSleepSamples(sleepSamples)
            
            await MainActor.run {
                self.sleepData = processedData
                print("Loaded \(processedData.count) sleep log\(processedData.count == 1 ? "" : "s")")
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("Failed to load sleep data: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Sleep Chart Data Loading
    
    func loadSleepChartData(for filter: TimeFilter) async {
        do {
            let sleepSamples = try await fetchSleepSamples(for: filter)
            let processedData = processSleepSamplesForChart(sleepSamples, for: filter)
            
            await MainActor.run {
                self.sleepChartData = processedData
            }
        } catch {
            await MainActor.run {
                self.sleepChartData = []
                print("Failed to load sleep chart data: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Sleep Sample Fetching
    
    private func fetchSleepSamples(for filter: TimeFilter) async throws -> [HKCategorySample] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthError.failedToCreateType
        }
        
        let (startDate, endDate) = dateRange(for: filter)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(throwing: HealthError.noSamplesFound)
                    return
                }
                
                continuation.resume(returning: sleepSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepSamples(last30Days: Bool) async throws -> [HKCategorySample] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthError.failedToCreateType
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate)! // Last 14 days
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(throwing: HealthError.noSamplesFound)
                    return
                }
                
                continuation.resume(returning: sleepSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Add Sleep Log
    
    func addSleepLog(bedtime: Date, sleepTime: Date?, wakeTime: Date, outOfBedTime: Date?) async {
        do {
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                await MainActor.run {
                    self.error = HealthError.failedToCreateType
                }
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
            try await saveSamples(samplesToSave)
            
            let duration = wakeTime.timeIntervalSince(asleepStart)
            let hours = Int(duration) / 3600
            let minutes = Int(duration) % 3600 / 60
            print("Sleep log saved successfully! Duration: \(hours)h \(minutes)m")
            
            // Reload data to reflect changes
            await loadSleepChartData(for: .today)
            await loadSleepData()
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    private func saveSamples(_ samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(samples) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? HealthError.saveFailed)
                }
            }
        }
    }
    
    // MARK: - Delete Sleep Session
    
    func deleteSleepSession(_ sleepData: SleepData) async {
        do {
            guard let samplesToDelete = samplesBySessionId[sleepData.sessionId] else {
                await MainActor.run {
                    self.error = HealthError.noSamplesFound
                }
                return
            }
            
            print("Deleting sleep session...")
            
            try await deleteSamples(samplesToDelete)
            
            await MainActor.run {
                // Remove from local storage
                self.samplesBySessionId.removeValue(forKey: sleepData.sessionId)
                
                // Remove from displayed data
                self.sleepData.removeAll { $0.sessionId == sleepData.sessionId }
                
                let duration = sleepData.formattedDuration
                print("Sleep session deleted (\(duration))")
            }
            
            // Reload data to reflect changes
            await loadSleepChartData(for: .today)
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    private func deleteSamples(_ samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.delete(samples) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? HealthError.saveFailed)
                }
            }
        }
    }
}

// MARK: - Helper Methods
extension HealthManager {
    private func dateRange(for filter: TimeFilter) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return (startOfMonth, endOfMonth)
        }
    }
    
    private func formatTimestamp(_ date: Date, for filter: TimeFilter) -> String {
        let formatter = DateFormatter()
        switch filter {
        case .today:
            formatter.dateFormat = "HH:mm"
        case .thisWeek:
            formatter.dateFormat = "EEE"
        case .thisMonth:
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
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
                    date: earliestStart,
                    bedtime: earliestStart,
                    wakeTime: latestEnd,
                    duration: totalSleepDuration,
                    sessionId: sessionId
                )
                
                result.append(sleepData)
            }
        }
        
        return result.sorted { $0.date > $1.date }
    }
    
    private func processSleepSamplesForChart(_ samples: [HKCategorySample], for filter: TimeFilter) -> [SleepChartData] {
        let calendar = Calendar.current
        var sleepByDay: [Date: Double] = [:]
        
        // Only process asleep samples for chart data
        let asleepSamples = samples.filter {
            $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
            $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
            $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
            $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
            $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        }
        
        for sample in asleepSamples {
            let day = calendar.startOfDay(for: sample.startDate)
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600 // Convert to hours
            sleepByDay[day, default: 0] += duration
        }
        
        return sleepByDay.map { date, duration in
            SleepChartData(
                date: date,
                duration: duration,
                quality: duration >= 7 ? "Good" : duration >= 6 ? "Fair" : "Poor",
                timestamp: formatTimestamp(date, for: filter)
            )
        }.sorted { $0.date < $1.date }
    }
    
    // Mock data generation for demo purposes
    private func generateMockHeartRateData(for filter: TimeFilter) -> [HeartRateData] {
        let calendar = Calendar.current
        let now = Date()
        var data: [HeartRateData] = []
        
        switch filter {
        case .today:
            for hour in stride(from: 0, to: 24, by: 2) {
                let date = calendar.date(byAdding: .hour, value: -23 + hour, to: now)!
                data.append(HeartRateData(
                    date: date,
                    heartRate: Double.random(in: 60...100),
                    timestamp: formatTimestamp(date, for: filter)
                ))
            }
        case .thisWeek:
            for day in 0..<7 {
                let date = calendar.date(byAdding: .day, value: -6 + day, to: now)!
                data.append(HeartRateData(
                    date: date,
                    heartRate: Double.random(in: 65...95),
                    timestamp: formatTimestamp(date, for: filter)
                ))
            }
        case .thisMonth:
            for day in stride(from: 0, to: 30, by: 2) {
                let date = calendar.date(byAdding: .day, value: -29 + day, to: now)!
                data.append(HeartRateData(
                    date: date,
                    heartRate: Double.random(in: 65...95),
                    timestamp: formatTimestamp(date, for: filter)
                ))
            }
        }
        
        return data
    }
}
