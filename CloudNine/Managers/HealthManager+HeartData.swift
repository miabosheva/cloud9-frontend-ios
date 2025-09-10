import Foundation
import HealthKit

extension HealthManager {
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
}
