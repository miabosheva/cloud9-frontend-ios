import Foundation
import HealthKit

extension HealthManager {
    
    private var metadataService: SleepMetadataService {
        return LocalSleepMetadataService()
    }
    
    // MARK: - Storage for tracking last sync
    private var lastHealthKitSyncKey: String { "lastHealthKitSync" }
    
    private var lastHealthKitSync: Date? {
        get {
            UserDefaults.standard.object(forKey: lastHealthKitSyncKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastHealthKitSyncKey)
        }
    }
    
    // MARK: - Delete All Sleep Data (HealthKit + Local)
    func deleteAllSleepData() async {
        do {
            print("Deleting ALL sleep data from HealthKit and local storage...")
            
            let samples = try await fetchSleepSamples()

            if !samples.isEmpty {
                try await deleteSample(samples)
                print("Deleted \(samples.count) sleep samples from HealthKit")
            } else {
                print("No HealthKit sleep samples found to delete")
            }

            // Clear local variables
            sleepData.removeAll()
            samplesBySessionId.removeAll()
            lastHealthKitSync = nil

            // Clear metadata
            try await metadataService.deleteAllMetadata()
            print("Deleted all local sleep metadata")

            print("✅ All sleep data successfully deleted")
        } catch {
            self.error = error
            print("❌ Failed to delete all sleep data: \(error.localizedDescription)")
        }
    }

    // MARK: - Enhanced Load Sleep Data with Smart Fetching
    func loadSleepData() async {
        do {
            // Always load existing metadata first
            let metadataDict = metadataService.loadAllMetadata()
            
            // Check if we need to fetch from HealthKit
            let needsHealthKitFetch = await shouldFetchFromHealthKit()
            
            if needsHealthKitFetch {
                print("New HealthKit data detected, fetching...")
                
                // Fetch only new data from HealthKit
                let newSleepSamples = try await fetchNewSleepSamples()
                
                if !newSleepSamples.isEmpty {
                    // Process new samples and merge with existing data
                    let newHealthKitSleepData = processSleepSamples(newSleepSamples)
                    
                    // Merge new data with existing sleepData, avoiding duplicates
                    mergeNewSleepData(newHealthKitSleepData)
                    
                    // Update last sync timestamp
                    lastHealthKitSync = Date()
                }
            } else {
                print("No new HealthKit data, using cached sleep data")
            }
            
            // Apply metadata to all sleep data (both existing and new)
            applyMetadataToSleepData(metadataDict)
            
            // Fill missing days with schedule
            sleepData = fillMissingDaysWithSchedule(sleepData)
            
            print("Loaded \(sleepData.count) sleep logs with metadata")
            
        } catch {
            self.error = error
            print("Failed to load sleep data with metadata: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Check if HealthKit fetch is needed
    private func shouldFetchFromHealthKit() async -> Bool {
        // Always fetch on first run
        guard let lastSync = lastHealthKitSync else {
            return true
        }
        
        // Check if there are any new samples since last sync
        do {
            let recentSamples = try await fetchSleepSamplesSince(lastSync)
            return !recentSamples.isEmpty
        } catch {
            print("Error checking for new HealthKit data: \(error.localizedDescription)")
            // On error, be safe and fetch
            return true
        }
    }
    
    // MARK: - Fetch only new sleep samples
    private func fetchNewSleepSamples() async throws -> [HKCategorySample] {
        if let lastSync = lastHealthKitSync {
            // Fetch samples since last sync
            return try await fetchSleepSamplesSince(lastSync)
        } else {
            // First time fetch - get last 30 days
            return try await fetchSleepSamples()
        }
    }
    
    // MARK: - Fetch sleep samples since specific date
    private func fetchSleepSamplesSince(_ sinceDate: Date) async throws -> [HKCategorySample] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthError.failedToCreateType
        }
        
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: sinceDate, end: endDate, options: .strictStartDate)
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
    
    // MARK: - Merge new sleep data with existing
    private func mergeNewSleepData(_ newSleepData: [SleepData]) {
        let existingIds = Set(sleepData.map { $0.id })
        
        for newItem in newSleepData {
            // Check for ID match first
            if existingIds.contains(newItem.id) {
                continue
            }
            
            // Check for time-based duplicates (same bedtime/wake time)
            let isDuplicate = sleepData.contains { existing in
                abs(existing.bedtime.timeIntervalSince(newItem.bedtime)) < 60 && // Within 1 minute
                abs(existing.wakeTime.timeIntervalSince(newItem.wakeTime)) < 60
            }
            
            if !isDuplicate {
                sleepData.append(newItem)
            } else {
                print("Skipping duplicate sleep entry for \(newItem.bedtime)")
            }
        }
        
        // Sort by date (most recent first)
        sleepData.sort { $0.date > $1.date }
    }
    
    // MARK: - Apply metadata to sleep data
    private func applyMetadataToSleepData(_ metadataDict: [String: SleepData]) {
        for (index, sleepItem) in sleepData.enumerated() {
            if let metadataItem = metadataDict[sleepItem.id] {
                var enhanced = sleepItem
                enhanced.sleepQuality = metadataItem.sleepQuality
                enhanced.description = metadataItem.description
                enhanced.tags = metadataItem.tags
                enhanced.isLocalOnly = metadataItem.isLocalOnly
                enhanced.lastSyncedAt = metadataItem.lastSyncedAt
                enhanced.needsSync = metadataItem.needsSync
                sleepData[index] = enhanced
            }
        }
    }
    
    // MARK: - Force refresh from HealthKit
    func forceRefreshFromHealthKit() async {
        print("Force refreshing all data from HealthKit...")
        
        // Clear existing data and sync timestamp
        sleepData.removeAll()
        samplesBySessionId.removeAll()
        lastHealthKitSync = nil
        
        // Reload everything
        await loadSleepData()
    }
    
    // MARK: - Update Sleep Log with proper date handling
    func updateSleepLog(
        sleepDataId: String,
        bedtime: Date? = nil,
        wakeTime: Date? = nil,
        sleepQuality: SleepQuality?,
        description: String?,
        tags: [String] = []
    ) async {
        do {
            // Find the sleep data
            guard let index = sleepData.firstIndex(where: { $0.id == sleepDataId }) else {
                throw HealthError.noSamplesFound
            }
            
            let currentSleepData = sleepData[index]
            let newBedtime = bedtime ?? currentSleepData.bedtime
            let newWakeTime = wakeTime ?? currentSleepData.wakeTime
            
            // If times are being updated, validate no overlap with other sleep logs
            if bedtime != nil || wakeTime != nil {
                // Filter out the current sleep log from overlap check
                let otherSleepData = sleepData.filter { $0.savedFlag && $0.id != sleepDataId }
                
                for existing in otherSleepData {
                    if hasTimeOverlap(
                        start1: newBedtime, end1: newWakeTime,
                        start2: existing.bedtime, end2: existing.wakeTime
                    ) {
                        throw HealthError.sleepLogExists
                    }
                }
                
                // Update HealthKit if times changed
                if let samples = samplesBySessionId[sleepDataId] {
                    // Delete old samples
                    try await deleteSample(samples)
                    
                    // Create new sample with updated times
                    guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                        throw HealthError.failedToCreateType
                    }
                    
                    let updatedSample = HKCategorySample(
                        type: sleepType,
                        value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                        start: newBedtime,
                        end: newWakeTime
                    )
                    
                    try await saveSamples([updatedSample])
                    
                    // Update samples dictionary
                    samplesBySessionId[sleepDataId] = [updatedSample]
                    
                    // Reset sync timestamp to trigger refresh on next load
                    lastHealthKitSync = nil
                }
            }
            
            // Update the local data with proper date calculation
            var updatedSleepData = sleepData[index]
            updatedSleepData.bedtime = newBedtime
            updatedSleepData.wakeTime = newWakeTime
            updatedSleepData.duration = newWakeTime.timeIntervalSince(newBedtime)
            
            // Update date field when bedtime changes
            if bedtime != nil {
                let calendar = Calendar.current
                updatedSleepData.date = calendar.startOfDay(for: newBedtime)
            }
            
            updatedSleepData.sleepQuality = sleepQuality
            updatedSleepData.description = description
            updatedSleepData.tags = tags
            updatedSleepData.needsSync = true
            updatedSleepData.isLocalOnly = true
            
            sleepData[index] = updatedSleepData
            
            // Save metadata
            try await metadataService.saveMetadata(updatedSleepData)
            
            let timeUpdate = (bedtime != nil || wakeTime != nil) ? " and times" : ""
            print("Sleep metadata\(timeUpdate) updated successfully")
            
            // Sync to backend
            Task {
                try? await metadataService.syncPendingMetadata()
            }
            
        } catch {
            self.error = error
            print("Error updating sleep log: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Enhanced Delete with proper metadata cleanup
    func deleteSleepSession(_ sleepData: SleepData) async {
        do {
            // Delete from HealthKit
            if let sampleToDelete = samplesBySessionId[sleepData.id] {
                print("Found \(sampleToDelete.count) HealthKit samples to delete")
                
                // Delete from HealthKit
                try await deleteSample(sampleToDelete)
                samplesBySessionId.removeValue(forKey: sleepData.id)
                print("Successfully deleted from HealthKit")
                
                // Reset sync timestamp to trigger refresh on next load
                lastHealthKitSync = nil
            } else {
                print("No HealthKit samples found for ID: \(sleepData.id)")
            }
            
            // Delete metadata from local storage
            try await metadataService.deleteMetadata(for: sleepData.id)
            
            // Remove from local array
            self.sleepData.removeAll { $0.id == sleepData.id }
            
            print("Sleep session and metadata deleted")
        } catch {
            self.error = error
            print("Error deleting sleep session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - FIXED Mark Log as Saved (prevents duplicates)
    func markLogAsSaved(sleepLog: SleepData) async {
        do {
            // Check for overlaps with better logic
            try await validateNoOverlap(bedtime: sleepLog.bedtime, wakeTime: sleepLog.wakeTime)
            
            // Save to HealthKit
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                throw HealthError.failedToCreateType
            }
            
            let asleepSample = HKCategorySample(
                type: sleepType,
                value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                start: sleepLog.bedtime,
                end: sleepLog.wakeTime
            )
            
            try await saveSamples([asleepSample])
            
            // Find and update the existing log
            guard let index = sleepData.firstIndex(where: { $0.id == sleepLog.id }) else {
                throw HealthError.invalidSampleType
            }
            
            // Update the existing log to mark as saved
            var updatedLog = sleepData[index]
            updatedLog.savedFlag = true
            updatedLog.duration = sleepLog.wakeTime.timeIntervalSince(sleepLog.bedtime)
            
            // Store the HealthKit sample with the SAME ID to prevent duplicates
            samplesBySessionId[sleepLog.id] = [asleepSample]
            
            // Update the array
            sleepData[index] = updatedLog
            
            // DON'T reset sync timestamp - just update lastHealthKitSync to now
            // This prevents unnecessary re-fetching
            lastHealthKitSync = Date()
            
            print("Sleep log marked as saved successfully! Duration: \(updatedLog.formattedDuration)")
            
        } catch {
            self.error = error
            print("Error marking sleep log as saved: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Add Sleep Log with sync timestamp reset
    func addSleepLog(
        bedtime: Date,
        wakeTime: Date,
        sleepQuality: SleepQuality?,
        description: String?,
        tags: [String] = []
    ) async {
        do {
            // Check for overlaps with better logic
            try await validateNoOverlap(bedtime: bedtime, wakeTime: wakeTime)
            
            // Save to HealthKit
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                throw HealthError.failedToCreateType
            }
            
            let asleepSample = HKCategorySample(
                type: sleepType,
                value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                start: bedtime,
                end: wakeTime
            )
            
            try await saveSamples([asleepSample])
            
            // Create SleepData with metadata
            let calendar = Calendar.current
            let date = calendar.startOfDay(for: bedtime)
            let duration = wakeTime.timeIntervalSince(bedtime)
            
            var newSleepData = SleepData(
                date: date,
                bedtime: bedtime,
                wakeTime: wakeTime,
                duration: duration,
                savedFlag: true,
                sleepQuality: sleepQuality,
                description: description
            )
            newSleepData.tags = tags
            newSleepData.needsSync = newSleepData.hasMetadata
            
            // Save metadata locally
            if newSleepData.hasMetadata {
                try await metadataService.saveMetadata(newSleepData)
            }
            
            // Update local array
            sleepData.append(newSleepData)
            sleepData.sort { $0.date > $1.date }
            
            // Reset sync timestamp since we added new data
            lastHealthKitSync = nil
            
            print("Sleep log with metadata saved successfully! Duration: \(newSleepData.formattedDuration)")
            
            // Sync to backend if needed
            if newSleepData.needsSync {
                Task {
                    try? await metadataService.syncPendingMetadata()
                }
            }
            
        } catch {
            self.error = error
            print("Error adding sleep log: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Process Sleep Samples
    private func processSleepSamples(_ samples: [HKCategorySample]) -> [SleepData] {
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
    
    // MARK: - Fill Missing Days with Schedule
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
    
    // MARK: - HealthKit Helper Methods
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
    
    private func fetchSleepSamples() async throws -> [HKCategorySample] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthError.failedToCreateType
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate)!
        
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
    
    // MARK: - Data Access Methods
    func getSleepDataInRange(startDate: Date, endDate: Date) -> [SleepData] {
        return sleepData.filter { sleepItem in
            sleepItem.bedtime >= startDate && sleepItem.bedtime <= endDate
        }
    }
    
    func getUnsyncedMetadata() -> [SleepData] {
        return sleepData.filter { $0.needsSync && $0.hasMetadata }
    }
    
    func markAsSynced(sleepDataId: String) async {
        guard let index = sleepData.firstIndex(where: { $0.id == sleepDataId }) else { return }
        
        sleepData[index].needsSync = false
        sleepData[index].isLocalOnly = false
        sleepData[index].lastSyncedAt = Date()
        
        do {
            try await metadataService.saveMetadata(sleepData[index])
        } catch {
            print("Error updating sync status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sleep Chart Data
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
}
