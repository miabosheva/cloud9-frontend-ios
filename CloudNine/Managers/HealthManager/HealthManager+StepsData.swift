import Foundation
import HealthKit

extension HealthManager {
    // MARK: - Steps Data Loading
    func loadStepsData(for filter: StepsFilter) async throws {
        do {
            let stepSamples = try await fetchStepSamples(for: filter)
            let calendar = Calendar.current
            
            // Group samples based on the filter
            let groupedSamples: [Date: [HKQuantitySample]] = Dictionary(grouping: stepSamples) { sample in
                switch filter {
                case .today:
                    // For today, group by hour to show hourly breakdown
                    return calendar.dateInterval(of: .hour, for: sample.startDate)?.start ?? sample.startDate
                case .thisWeek:
                    // For this week, group by day
                    return calendar.startOfDay(for: sample.startDate)
                case .thisMonth:
                    // For this month, group by day
                    return calendar.startOfDay(for: sample.startDate)
                }
            }
            
            // Sum steps for each group
            let aggregatedData: [StepsData] = groupedSamples.map { (groupDate, samples) in
                let totalSteps = samples
                    .map { Int($0.quantity.doubleValue(for: HKUnit.count())) }
                    .reduce(0, +)
                
                return StepsData(
                    date: groupDate,
                    steps: totalSteps,
                    timestamp: formatTimestamp(groupDate, for: filter)
                )
            }.sorted { $0.date < $1.date }
            
            self.stepsData = aggregatedData
            
        } catch {
            throw error
        }
    }
    
    private func fetchStepSamples(for filter: StepsFilter) async throws -> [HKQuantitySample] {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthError.failedToCreateType
        }
        
        let (startDate, endDate) = dateRange(for: filter)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepCountType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let stepSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(throwing: HealthError.noSamplesFound)
                    return
                }
                
                continuation.resume(returning: stepSamples)
            }
            
            healthStore.execute(query)
        }
    }
}
