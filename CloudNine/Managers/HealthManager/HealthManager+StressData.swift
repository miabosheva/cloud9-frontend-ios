import Foundation
import HealthKit

extension HealthManager {
    
    // MARK: - Heart Rate Variability (HRV)
    
    /// Fetch Heart Rate Variability samples
    func fetchHeartRateVariability(startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthError.failedToCreateType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let hrvSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: hrvSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Get average HRV for a date range
    func getAverageHRV(startDate: Date, endDate: Date) async throws -> Double? {
        let samples = try await fetchHeartRateVariability(startDate: startDate, endDate: endDate)
        
        guard !samples.isEmpty else { return nil }
        
        let unit = HKUnit.secondUnit(with: .milli) // milliseconds
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        return values.reduce(0, +) / Double(values.count)
    }
    
    // MARK: - Resting Heart Rate
    
    /// Fetch resting heart rate samples
    func fetchRestingHeartRate(startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthError.failedToCreateType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let restingHRSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: restingHRSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Get most recent resting heart rate
    func getRestingHeartRate(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? date
        
        let samples = try await fetchRestingHeartRate(startDate: startDate, endDate: endDate)
        
        // Get the most recent sample
        guard let mostRecent = samples.last else { return nil }
        
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        return mostRecent.quantity.doubleValue(for: unit)
    }
    
    // MARK: - Steps
    
    /// Fetch step count samples
    func fetchSteps(startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthError.failedToCreateType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepsType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let stepSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: stepSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Get total step count for a date
    func getStepCount(for date: Date) async throws -> Double {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? date
        
        let samples = try await fetchSteps(startDate: startDate, endDate: endDate)
        
        let unit = HKUnit.count()
        return samples.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }
    }
    
    // MARK: - Active Energy (Activity Level)
    
    /// Fetch active energy burned samples
    func fetchActiveEnergy(startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthError.failedToCreateType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: energyType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let energySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: energySamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Get total active energy burned for a date
    func getActiveEnergy(for date: Date) async throws -> Double {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? date
        
        let samples = try await fetchActiveEnergy(startDate: startDate, endDate: endDate)
        
        let unit = HKUnit.kilocalorie()
        return samples.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }
    }
    
    // MARK: - Heart Rate During Sleep
    
    /// Get average heart rate during a sleep session
    func getHeartRateDuringSleep(bedtime: Date, wakeTime: Date) async throws -> Double? {
        // Fetch heart rate samples for the sleep period
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthError.failedToCreateType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: bedtime, end: wakeTime, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
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
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: heartRateSamples)
            }
            
            healthStore.execute(query)
        }
        
        guard !samples.isEmpty else { return nil }
        
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        return values.reduce(0, +) / Double(values.count)
    }
}
