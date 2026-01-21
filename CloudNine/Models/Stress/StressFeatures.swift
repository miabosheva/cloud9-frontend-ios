import Foundation

/// Features extracted from health data for stress prediction
struct StressFeatures: Codable {
    // Sleep features
    var sleepDuration: Double // hours
    var sleepQuality: Double // 0-5 scale (from SleepQuality enum)
    var bedtimeConsistency: Double // standard deviation of bedtime in hours
    var wakeTimeConsistency: Double // standard deviation of wake time in hours
    
    // Heart rate features
    var restingHeartRate: Double // bpm
    var heartRateVariability: Double? // ms (if available)
    var heartRateDuringSleep: Double // average bpm during sleep
    
    // Activity features
    var activityLevel: Double // active energy burned in kcal
    var stepsCount: Double // number of steps
    
    // Temporal features
    var dayOfWeek: Int // 0-6 (Sunday = 0)
    var timeSinceLastSleep: Double // hours since last sleep session
    
    init(
        sleepDuration: Double = 0,
        sleepQuality: Double = 0,
        bedtimeConsistency: Double = 0,
        wakeTimeConsistency: Double = 0,
        restingHeartRate: Double = 0,
        heartRateVariability: Double? = nil,
        heartRateDuringSleep: Double = 0,
        activityLevel: Double = 0,
        stepsCount: Double = 0,
        dayOfWeek: Int = 0,
        timeSinceLastSleep: Double = 0
    ) {
        self.sleepDuration = sleepDuration
        self.sleepQuality = sleepQuality
        self.bedtimeConsistency = bedtimeConsistency
        self.wakeTimeConsistency = wakeTimeConsistency
        self.restingHeartRate = restingHeartRate
        self.heartRateVariability = heartRateVariability
        self.heartRateDuringSleep = heartRateDuringSleep
        self.activityLevel = activityLevel
        self.stepsCount = stepsCount
        self.dayOfWeek = dayOfWeek
        self.timeSinceLastSleep = timeSinceLastSleep
    }
    
    /// Convert to array format for ML model input
    func toArray() -> [Double] {
        var array: [Double] = [
            sleepDuration,
            sleepQuality,
            bedtimeConsistency,
            wakeTimeConsistency,
            restingHeartRate,
            heartRateDuringSleep,
            activityLevel,
            stepsCount,
            Double(dayOfWeek),
            timeSinceLastSleep
        ]
        
        // Add HRV if available, otherwise use 0
        array.append(heartRateVariability ?? 0.0)
        
        return array
    }
}
