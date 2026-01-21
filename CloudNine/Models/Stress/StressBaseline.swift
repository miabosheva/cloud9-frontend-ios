import Foundation

/// Baseline statistics calculated from 7-day training period
struct StressBaseline: Codable {
    var startDate: Date
    var endDate: Date
    var isComplete: Bool // True when 7 days of data collected
    
    // Mean values for each feature
    var meanSleepDuration: Double
    var meanSleepQuality: Double
    var meanBedtimeConsistency: Double
    var meanWakeTimeConsistency: Double
    var meanRestingHeartRate: Double
    var meanHeartRateVariability: Double?
    var meanHeartRateDuringSleep: Double
    var meanActivityLevel: Double
    var meanStepsCount: Double
    var meanTimeSinceLastSleep: Double
    
    // Standard deviations for each feature
    var stdSleepDuration: Double
    var stdSleepQuality: Double
    var stdBedtimeConsistency: Double
    var stdWakeTimeConsistency: Double
    var stdRestingHeartRate: Double
    var stdHeartRateVariability: Double?
    var stdHeartRateDuringSleep: Double
    var stdActivityLevel: Double
    var stdStepsCount: Double
    var stdTimeSinceLastSleep: Double
    
    init(
        startDate: Date,
        endDate: Date,
        isComplete: Bool = false,
        meanSleepDuration: Double = 0,
        meanSleepQuality: Double = 0,
        meanBedtimeConsistency: Double = 0,
        meanWakeTimeConsistency: Double = 0,
        meanRestingHeartRate: Double = 0,
        meanHeartRateVariability: Double? = nil,
        meanHeartRateDuringSleep: Double = 0,
        meanActivityLevel: Double = 0,
        meanStepsCount: Double = 0,
        meanTimeSinceLastSleep: Double = 0,
        stdSleepDuration: Double = 0,
        stdSleepQuality: Double = 0,
        stdBedtimeConsistency: Double = 0,
        stdWakeTimeConsistency: Double = 0,
        stdRestingHeartRate: Double = 0,
        stdHeartRateVariability: Double? = nil,
        stdHeartRateDuringSleep: Double = 0,
        stdActivityLevel: Double = 0,
        stdStepsCount: Double = 0,
        stdTimeSinceLastSleep: Double = 0
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.isComplete = isComplete
        self.meanSleepDuration = meanSleepDuration
        self.meanSleepQuality = meanSleepQuality
        self.meanBedtimeConsistency = meanBedtimeConsistency
        self.meanWakeTimeConsistency = meanWakeTimeConsistency
        self.meanRestingHeartRate = meanRestingHeartRate
        self.meanHeartRateVariability = meanHeartRateVariability
        self.meanHeartRateDuringSleep = meanHeartRateDuringSleep
        self.meanActivityLevel = meanActivityLevel
        self.meanStepsCount = meanStepsCount
        self.meanTimeSinceLastSleep = meanTimeSinceLastSleep
        self.stdSleepDuration = stdSleepDuration
        self.stdSleepQuality = stdSleepQuality
        self.stdBedtimeConsistency = stdBedtimeConsistency
        self.stdWakeTimeConsistency = stdWakeTimeConsistency
        self.stdRestingHeartRate = stdRestingHeartRate
        self.stdHeartRateVariability = stdHeartRateVariability
        self.stdHeartRateDuringSleep = stdHeartRateDuringSleep
        self.stdActivityLevel = stdActivityLevel
        self.stdStepsCount = stdStepsCount
        self.stdTimeSinceLastSleep = stdTimeSinceLastSleep
    }
    
    /// Calculate z-score for a feature value (deviation from baseline)
    func zScore(for feature: StressFeatures) -> StressFeatures {
        return StressFeatures(
            sleepDuration: calculateZScore(value: feature.sleepDuration, mean: meanSleepDuration, std: stdSleepDuration),
            sleepQuality: calculateZScore(value: feature.sleepQuality, mean: meanSleepQuality, std: stdSleepQuality),
            bedtimeConsistency: calculateZScore(value: feature.bedtimeConsistency, mean: meanBedtimeConsistency, std: stdBedtimeConsistency),
            wakeTimeConsistency: calculateZScore(value: feature.wakeTimeConsistency, mean: meanWakeTimeConsistency, std: stdWakeTimeConsistency),
            restingHeartRate: calculateZScore(value: feature.restingHeartRate, mean: meanRestingHeartRate, std: stdRestingHeartRate),
            heartRateVariability: feature.heartRateVariability != nil && meanHeartRateVariability != nil ? calculateZScore(value: feature.heartRateVariability!, mean: meanHeartRateVariability!, std: stdHeartRateVariability ?? 1.0) : nil,
            heartRateDuringSleep: calculateZScore(value: feature.heartRateDuringSleep, mean: meanHeartRateDuringSleep, std: stdHeartRateDuringSleep),
            activityLevel: calculateZScore(value: feature.activityLevel, mean: meanActivityLevel, std: stdActivityLevel),
            stepsCount: calculateZScore(value: feature.stepsCount, mean: meanStepsCount, std: stdStepsCount),
            dayOfWeek: feature.dayOfWeek, // Day of week doesn't need z-score
            timeSinceLastSleep: calculateZScore(value: feature.timeSinceLastSleep, mean: meanTimeSinceLastSleep, std: stdTimeSinceLastSleep)
        )
    }
    
    private func calculateZScore(value: Double, mean: Double, std: Double) -> Double {
        guard std > 0 else { return 0 }
        return (value - mean) / std
    }
}
