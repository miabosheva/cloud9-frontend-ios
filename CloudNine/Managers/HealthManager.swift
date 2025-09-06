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
    
    @ObservationIgnored private let healthStore = HKHealthStore()
    
    var sleepChartData: [SleepChartData] = []
    
    var heartRateData: [HeartRateData] = []
    var sleepData: [SleepData] = []
    
    var userInfo = UserInfo()
    
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
        await loadSleepData()
        loadSleepSamplesForChart(filter: .thisWeek)
    }
    
    // MARK: - Heart Rate Data Loading
    //    For .today and .yesterday: Average per hour.
    //    For .thisWeek and .thisMonth: Average per day.
    func loadHeartRateData(for filter: HeartFilter) async {
        do {
            let heartRateSamples = try await fetchHeartRateSamples(for: filter)
            let calendar = Calendar.current
            
            if heartRateSamples.count < 20 {
                let data =  heartRateSamples.map { sample in
                    HeartRateData(
                        date: sample.startDate,
                        heartRate: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())),
                        timestamp: formatTimestamp(sample.startDate, for: filter))
                }.sorted { $0.date < $1.date }
                
                self.heartRateData = data
                return
            }
            
            // Group samples based on the filter
            let groupedSamples: [Date: [HKQuantitySample]] = Dictionary(grouping: heartRateSamples) { sample in
                switch filter {
                case .today, .yesterday:
                    // Group by hour
                    return calendar.dateInterval(of: .hour, for: sample.startDate)?.start ?? sample.startDate
                case .thisWeek, .thisMonth:
                    // Group by day
                    return calendar.startOfDay(for: sample.startDate)
                }
            }
            
            // Map each group to average HeartRateData
            let aggregatedData: [HeartRateData] = groupedSamples.map { (groupDate, samples) in
                let heartRate = samples
                    .map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) }
                    .reduce(0, +) / Double(samples.count)
                
                return HeartRateData(
                    date: groupDate,
                    heartRate: heartRate,
                    timestamp: formatTimestamp(groupDate, for: filter)
                )
            }.sorted { $0.date < $1.date }
            
            self.heartRateData = aggregatedData
            
        } catch {
            //            await MainActor.run {
            //                self.heartRateChartData = generateMockHeartRateData(for: filter)
            //                print("Failed to load heart rate data: \(error.localizedDescription)")
            //            }
            print(error.localizedDescription)
        }
    }
    
    private func fetchHeartRateSamples(for filter: HeartFilter) async throws -> [HKQuantitySample] {
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
            // load sleep data
            sleepData = processSleepSamples(sleepSamples)
            
            // Fill missing days with schedule (planned bedtime/wake)
            let filled = fillMissingDaysWithSchedule(sleepData)
            
            sleepData = filled
            print("Loaded \(sleepData.count) sleep logs")
        } catch {
            self.error = error
            print("Failed to load sleep data: \(error.localizedDescription)")
        }
    }
    
    private func fillMissingDaysWithSchedule(_ logs: [SleepData]) -> [SleepData] {
        var result = logs
        let calendar = Calendar.current
        let endDate = Date()
        
        let existingDays = Set(logs.map { calendar.startOfDay(for: $0.date) })
        
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDate) else { continue }
            let startOfDay = calendar.startOfDay(for: day)
            
            if !existingDays.contains(startOfDay) {
                // Combine date with user's bedtime and wakeTime
                let bedtime = combine(date: startOfDay, time: userInfo.bedtime)
                var wakeTime = combine(date: startOfDay, time: userInfo.wakeTime)
                
                // If wakeTime <= bedtime, add one day
                if wakeTime <= bedtime {
                    wakeTime = calendar.date(byAdding: .day, value: 1, to: wakeTime)!
                }
                
                let planned = SleepData(
                    id: "planned-\(startOfDay.timeIntervalSince1970)",
                    date: startOfDay,
                    bedtime: bedtime,
                    wakeTime: wakeTime,
                    duration: wakeTime.timeIntervalSince(bedtime),
                    savedFlag: false
                )
                result.append(planned)
            }
        }
        
        return result.sorted { $0.date > $1.date }
    }
    
    /// Combines a date with a time from another Date
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second
        
        return calendar.date(from: combined)!
    }
    
    func loadSleepSamplesForChart(filter: SleepFilter) {
        sleepChartData = processSleepChartData(for: filter)
    }
    
    func processSleepChartData(for filter: SleepFilter) -> [SleepChartData] {
        let calendar = Calendar.current
        var sleepByDay: [Date: Double] = [:]
        
        // Determine start of week
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        for sample in sleepData {
            let sampleDay = calendar.startOfDay(for: sample.date)
            
            // Only include samples in the current week if filter is .week
            if filter == .thisWeek && sampleDay < startOfWeek {
                continue
            }
            
            let duration = sample.wakeTime.timeIntervalSince(sample.bedtime) / 3600
            sleepByDay[sampleDay, default: 0] += duration
        }
        
        return sleepByDay.map { date, duration in
            SleepChartData(
                date: date,
                duration: duration,
                quality: duration >= 7 ? "Good" : duration >= 6 ? "Fair" : "Poor",
                timestamp: formatTimestamp(date, for: filter)
            )
        }
        .sorted { $0.date > $1.date }
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
    func addSleepLog(bedtime: Date, wakeTime: Date) async {
        do {
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                await MainActor.run {
                    self.error = HealthError.failedToCreateType
                }
                return
            }
            
            let filteredSleepData = sleepData.filter({ $0.savedFlag == true })
            for existing in filteredSleepData {
                if (bedtime < existing.wakeTime) && (wakeTime > existing.bedtime) {
                    print(error)
                    throw HealthError.sleepLogExists
                }
            }
            
            let asleepSample = HKCategorySample(
                type: sleepType,
                value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                start: bedtime,
                end: wakeTime
            )
            
            try await saveSamples([asleepSample])
            
            let duration = wakeTime.timeIntervalSince(bedtime)
            let hours = Int(duration) / 3600
            let minutes = Int(duration) % 3600 / 60
            print("Sleep log saved successfully! Duration: \(hours)h \(minutes)m")
            
            await loadSleepData()
        } catch {
            self.error = error
            print(error)
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
            guard let sampleToDelete = samplesBySessionId[sleepData.id] else {
                await MainActor.run {
                    self.error = HealthError.noSamplesFound
                }
                return
            }
            
            print("Deleting sleep session...")
            
            try await deleteSample(sampleToDelete)
            
            // Remove from local storage
            self.samplesBySessionId.removeValue(forKey: sleepData.id)
            
            // Remove from displayed data
            self.sleepData.removeAll { $0.id == sleepData.id }
            
            let duration = sleepData.formattedDuration
            print("Sleep session deleted (\(duration))")
            
            // Reload data to reflect changes
            await loadSleepData()
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    private func deleteSample(_ samples: [HKSample]) async throws {
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
    private func dateRange(for filter: HeartFilter) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        case .yesterday:
            let today = calendar.startOfDay(for: now)
            let startOfDay = calendar.date(byAdding: .day, value: -1, to: today)!
            let endOfDay = today
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
    
    private func dateRange(for filter: SleepFilter) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
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
    
    private func formatTimestamp(_ date: Date, for filter: HeartFilter) -> String {
        let formatter = DateFormatter()
        switch filter {
        case .today:
            formatter.dateFormat = "HH:mm"
        case .yesterday:
            formatter.dateFormat = "HH:mm"
        case .thisWeek:
            formatter.dateFormat = "EEE"
        case .thisMonth:
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
    
    private func formatTimestamp(_ date: Date, for filter: SleepFilter) -> String {
        let formatter = DateFormatter()
        switch filter {
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
                
                let id = "\(earliestStart.timeIntervalSince1970)-\(index)"
                
                // Store the samples for potential deletion
                samplesBySessionId[id] = sessionSamples
                
                let sleepData = SleepData(
                    id: id,
                    date: earliestStart,
                    bedtime: earliestStart,
                    wakeTime: latestEnd,
                    duration: totalSleepDuration,
                    savedFlag: true
                )
                
                result.append(sleepData)
            }
        }
        
        return result.sorted { $0.date > $1.date }
    }
}
