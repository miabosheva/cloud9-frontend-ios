import Foundation
import FirebaseFirestore
import FirebaseAuth

actor StressPredictionService {
    private let db = Firestore.firestore()
    
    init() {
    }
    
    private var userId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    private var baselineDocumentRef: DocumentReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId).collection("stress_data").document("baseline")
    }
    
    // MARK: - Feature Extraction
    
    /// Extract stress features for a specific date
    func extractFeatures(for date: Date, sleepData: [SleepData], healthManager: HealthManager) async throws -> StressFeatures {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        
        // Get sleep data for this day
        let daySleepData = sleepData.filter { sleep in
            calendar.isDate(sleep.date, inSameDayAs: date)
        }
        
        // Sleep features
        let sleepDuration = daySleepData.first?.durationInHours ?? 0
        let sleepQuality = daySleepData.first?.sleepQuality?.numericValue ?? 0
        
        // Calculate bedtime and wake time consistency from last 7 days
        let last7Days = calendar.date(byAdding: .day, value: -7, to: date) ?? date
        let recentSleepData = sleepData.filter { sleep in
            sleep.date >= last7Days && sleep.date <= date
        }
        
        let bedtimeConsistency = calculateBedtimeConsistency(sleepData: recentSleepData)
        let wakeTimeConsistency = calculateWakeTimeConsistency(sleepData: recentSleepData)
        
        // Heart rate features
        let restingHeartRate = try await healthManager.getRestingHeartRate(for: date) ?? 0
        let hrv = try await healthManager.getAverageHRV(startDate: dayStart, endDate: dayEnd)
        
        // Heart rate during sleep
        var heartRateDuringSleep: Double = 0
        if let sleep = daySleepData.first {
            heartRateDuringSleep = try await healthManager.getHeartRateDuringSleep(
                bedtime: sleep.bedtime,
                wakeTime: sleep.wakeTime
            ) ?? 0
        }
        
        // Activity features
        let activityLevel = try await healthManager.getActiveEnergy(for: date)
        let stepsCount = try await healthManager.getStepCount(for: date)
        
        // Temporal features
        let dayOfWeek = calendar.component(.weekday, from: date) - 1 // 0-6 (Sunday = 0)
        
        // Time since last sleep
        let timeSinceLastSleep: Double
        if let lastSleep = sleepData.sorted(by: { $0.date > $1.date }).first(where: { $0.date < date }) {
            let hoursSince = date.timeIntervalSince(lastSleep.wakeTime) / 3600.0
            timeSinceLastSleep = hoursSince
        } else {
            timeSinceLastSleep = 0
        }
        
        return StressFeatures(
            sleepDuration: sleepDuration,
            sleepQuality: sleepQuality,
            bedtimeConsistency: bedtimeConsistency,
            wakeTimeConsistency: wakeTimeConsistency,
            restingHeartRate: restingHeartRate,
            heartRateVariability: hrv,
            heartRateDuringSleep: heartRateDuringSleep,
            activityLevel: activityLevel,
            stepsCount: stepsCount,
            dayOfWeek: dayOfWeek,
            timeSinceLastSleep: timeSinceLastSleep
        )
    }
    
    // MARK: - Baseline Calculation
    
    /// Calculate baseline from 7 days of data
    func calculateBaseline(from features: [StressFeatures], startDate: Date, endDate: Date) -> StressBaseline {
        guard !features.isEmpty else {
            return StressBaseline(startDate: startDate, endDate: endDate, isComplete: false)
        }
        
        let isComplete = features.count >= 7
        
        // Calculate means
        let meanSleepDuration = features.map { $0.sleepDuration }.reduce(0, +) / Double(features.count)
        let meanSleepQuality = features.map { $0.sleepQuality }.reduce(0, +) / Double(features.count)
        let meanBedtimeConsistency = features.map { $0.bedtimeConsistency }.reduce(0, +) / Double(features.count)
        let meanWakeTimeConsistency = features.map { $0.wakeTimeConsistency }.reduce(0, +) / Double(features.count)
        let meanRestingHeartRate = features.map { $0.restingHeartRate }.reduce(0, +) / Double(features.count)
        let meanHeartRateDuringSleep = features.map { $0.heartRateDuringSleep }.reduce(0, +) / Double(features.count)
        let meanActivityLevel = features.map { $0.activityLevel }.reduce(0, +) / Double(features.count)
        let meanStepsCount = features.map { $0.stepsCount }.reduce(0, +) / Double(features.count)
        let meanTimeSinceLastSleep = features.map { $0.timeSinceLastSleep }.reduce(0, +) / Double(features.count)
        
        // HRV mean (only if available)
        let hrvValues = features.compactMap { $0.heartRateVariability }
        let meanHeartRateVariability = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)
        
        // Calculate standard deviations
        let stdSleepDuration = calculateStandardDeviation(values: features.map { $0.sleepDuration }, mean: meanSleepDuration)
        let stdSleepQuality = calculateStandardDeviation(values: features.map { $0.sleepQuality }, mean: meanSleepQuality)
        let stdBedtimeConsistency = calculateStandardDeviation(values: features.map { $0.bedtimeConsistency }, mean: meanBedtimeConsistency)
        let stdWakeTimeConsistency = calculateStandardDeviation(values: features.map { $0.wakeTimeConsistency }, mean: meanWakeTimeConsistency)
        let stdRestingHeartRate = calculateStandardDeviation(values: features.map { $0.restingHeartRate }, mean: meanRestingHeartRate)
        let stdHeartRateDuringSleep = calculateStandardDeviation(values: features.map { $0.heartRateDuringSleep }, mean: meanHeartRateDuringSleep)
        let stdActivityLevel = calculateStandardDeviation(values: features.map { $0.activityLevel }, mean: meanActivityLevel)
        let stdStepsCount = calculateStandardDeviation(values: features.map { $0.stepsCount }, mean: meanStepsCount)
        let stdTimeSinceLastSleep = calculateStandardDeviation(values: features.map { $0.timeSinceLastSleep }, mean: meanTimeSinceLastSleep)
        
        let stdHeartRateVariability = hrvValues.isEmpty ? nil : calculateStandardDeviation(values: hrvValues, mean: meanHeartRateVariability ?? 0)
        
        return StressBaseline(
            startDate: startDate,
            endDate: endDate,
            isComplete: isComplete,
            meanSleepDuration: meanSleepDuration,
            meanSleepQuality: meanSleepQuality,
            meanBedtimeConsistency: meanBedtimeConsistency,
            meanWakeTimeConsistency: meanWakeTimeConsistency,
            meanRestingHeartRate: meanRestingHeartRate,
            meanHeartRateVariability: meanHeartRateVariability,
            meanHeartRateDuringSleep: meanHeartRateDuringSleep,
            meanActivityLevel: meanActivityLevel,
            meanStepsCount: meanStepsCount,
            meanTimeSinceLastSleep: meanTimeSinceLastSleep,
            stdSleepDuration: stdSleepDuration,
            stdSleepQuality: stdSleepQuality,
            stdBedtimeConsistency: stdBedtimeConsistency,
            stdWakeTimeConsistency: stdWakeTimeConsistency,
            stdRestingHeartRate: stdRestingHeartRate,
            stdHeartRateVariability: stdHeartRateVariability,
            stdHeartRateDuringSleep: stdHeartRateDuringSleep,
            stdActivityLevel: stdActivityLevel,
            stdStepsCount: stdStepsCount,
            stdTimeSinceLastSleep: stdTimeSinceLastSleep
        )
    }
    
    /// Collect features for baseline training period (7 days)
    func collectBaselineFeatures(startDate: Date, sleepData: [SleepData], healthManager: HealthManager) async throws -> [StressFeatures] {
        let calendar = Calendar.current
        var features: [StressFeatures] = []
        
        // Get sleep data for the period
        let endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? Date()
        let periodSleepData = sleepData.filter { sleep in
            sleep.date >= startDate && sleep.date < endDate
        }
        
        // Collect features for each day
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let feature = try await extractFeatures(for: date, sleepData: periodSleepData, healthManager: healthManager)
            features.append(feature)
        }
        
        return features
    }
    
    // MARK: - Baseline Storage
    
    /// Save baseline to Firestore
    func saveBaseline(_ baseline: StressBaseline) async throws {
        guard let documentRef = baselineDocumentRef else {
            throw UserManagerError.userNotAuthenticated
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            
            let data = try encoder.encode(baseline)
            guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw UserManagerError.encodingFailed
            }
            
            try await documentRef.setData(dictionary, merge: true)
        } catch {
            if error is UserManagerError {
                throw error
            }
            throw UserManagerError.saveFailed(error)
        }
    }
    
    /// Load baseline from Firestore
    func loadBaseline() async throws -> StressBaseline? {
        guard let documentRef = baselineDocumentRef else {
            throw UserManagerError.userNotAuthenticated
        }
        
        do {
            let document = try await documentRef.getDocument()
            
            guard document.exists, let data = document.data() else {
                return nil
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            
            let baseline = try decoder.decode(StressBaseline.self, from: jsonData)
            return baseline
        } catch {
            throw UserManagerError.fetchFailed(error)
        }
    }
    
    // MARK: - Stress Prediction (Firebase Cloud Function)
    
    /// Predict stress index using Firebase Cloud Function
    func predictStress(features: StressFeatures, baseline: StressBaseline) async throws -> StressIndex {
        // Calculate z-scores (deviations from baseline)
        let zScores = baseline.zScore(for: features)
        
        // Prepare request payload
        let payload: [String: Any] = [
            "features": zScores.toArray(),
            "baseline_means": [
                baseline.meanSleepDuration,
                baseline.meanSleepQuality,
                baseline.meanBedtimeConsistency,
                baseline.meanWakeTimeConsistency,
                baseline.meanRestingHeartRate,
                baseline.meanHeartRateDuringSleep,
                baseline.meanActivityLevel,
                baseline.meanStepsCount,
                Double(baseline.startDate.timeIntervalSince1970),
                baseline.meanTimeSinceLastSleep
            ],
            "baseline_stds": [
                baseline.stdSleepDuration,
                baseline.stdSleepQuality,
                baseline.stdBedtimeConsistency,
                baseline.stdWakeTimeConsistency,
                baseline.stdRestingHeartRate,
                baseline.stdHeartRateDuringSleep,
                baseline.stdActivityLevel,
                baseline.stdStepsCount,
                1.0, // placeholder for time
                baseline.stdTimeSinceLastSleep
            ]
        ]
        
        // TODO: Call Firebase Cloud Function
        // For now, return a placeholder
        // In Phase 4, this will call: https://your-region-your-project.cloudfunctions.net/predictStress
        
        // Placeholder implementation - will be replaced with actual API call
        throw NSError(domain: "StressPredictionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Firebase Cloud Function not yet implemented"])
    }
    
    // MARK: - Helper Methods
    
    private func calculateBedtimeConsistency(sleepData: [SleepData]) -> Double {
        guard sleepData.count > 1 else { return 0 }
        
        let calendar = Calendar.current
        let bedtimes = sleepData.map { sleep in
            let components = calendar.dateComponents([.hour, .minute], from: sleep.bedtime)
            return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60.0
        }
        
        return calculateStandardDeviation(values: bedtimes, mean: bedtimes.reduce(0, +) / Double(bedtimes.count))
    }
    
    private func calculateWakeTimeConsistency(sleepData: [SleepData]) -> Double {
        guard sleepData.count > 1 else { return 0 }
        
        let calendar = Calendar.current
        let wakeTimes = sleepData.map { sleep in
            let components = calendar.dateComponents([.hour, .minute], from: sleep.wakeTime)
            return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60.0
        }
        
        return calculateStandardDeviation(values: wakeTimes, mean: wakeTimes.reduce(0, +) / Double(wakeTimes.count))
    }
    
    private func calculateStandardDeviation(values: [Double], mean: Double) -> Double {
        guard values.count > 1 else { return 0 }
        
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
