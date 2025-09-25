import SwiftUI
import Foundation

// Automated Sleep Debt Calculator
class AutomatedSleepDebtCalculator: SleepDebtCalculator {
    // User preferences for automation
    struct AutomationSettings {
        var primaryGoal: TrackingGoal = .balanced
        var dataQualityThreshold: Double = 0.7 // 70% data completeness
        var adaptiveStrategy: Bool = true
        var weeklyRecalculation: Bool = true
        var notificationThreshold: Double = 10.0 // hours of debt
    }
    
    private var settings: AutomationSettings
    private var dataQualityCache: [DateInterval: DataQuality] = [:]
    
    init(recommendedSleepHours: Double = 8.0,
         settings: AutomationSettings = AutomationSettings()) {
        self.settings = settings
        super.init(recommendedSleepHours: recommendedSleepHours)
    }
    
    // MARK: - Automated Strategy Selection
    
    func automaticCalculateDebt(sleepData: [SleepData],
                                period: DateInterval? = nil) -> AutomatedSleepDebtResult {
        
        let calculationPeriod = period ?? getDefaultPeriod()
        let dataQuality = assessDataQuality(sleepData: sleepData, period: calculationPeriod)
        let strategy = selectOptimalStrategy(dataQuality: dataQuality)
        
        let result = calculateCumulativeDebt(
            sleepData: sleepData,
            startDate: calculationPeriod.start,
            endDate: calculationPeriod.end
        )
        
        let automatedResult = AutomatedSleepDebtResult(
            baseResult: result,
            selectedStrategy: strategy,
            dataQuality: dataQuality,
            recommendations: generateRecommendations(result: result, dataQuality: dataQuality),
            automationSettings: settings
        )
        
        // Cache the data quality for future use
        dataQualityCache[calculationPeriod] = dataQuality
        
        return automatedResult
    }
    
    // MARK: - Data Quality Assessment
    
    func assessDataQuality(sleepData: [SleepData], period: DateInterval) -> DataQuality {
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: period.start, to: period.end).day ?? 1
        let availableDays = sleepData.filter { data in
            period.contains(data.date)
        }.count
        
        let completeness = Double(availableDays) / Double(totalDays)
        
        // Assess consistency (how regular is the data?)
        let consistency = assessConsistency(sleepData: sleepData, period: period)
        
        // Assess recency (are recent days missing?)
        let recency = assessRecency(sleepData: sleepData, period: period)
        
        // Check for weekend vs weekday patterns
        let hasWeekendPattern = assessWeekendPattern(sleepData: sleepData)
        
        return DataQuality(
            completeness: completeness,
            consistency: consistency,
            recency: recency,
            hasWeekendPattern: hasWeekendPattern,
            totalDays: totalDays,
            availableDays: availableDays
        )
    }
    
    private func assessConsistency(sleepData: [SleepData], period: DateInterval) -> Double {
        let filteredData = sleepData.filter { period.contains($0.date) }
        guard filteredData.count > 1 else { return 0.0 }
        
        let durations = filteredData.map { $0.durationInHours }
        let average = durations.reduce(0, +) / Double(durations.count)
        let variance = durations.map { pow($0 - average, 2) }.reduce(0, +) / Double(durations.count)
        
        // Convert variance to consistency score (lower variance = higher consistency)
        let maxVariance: Double = 4.0 // Assume 4 hours variance is max
        return max(0, 1.0 - (sqrt(variance) / maxVariance))
    }
    
    private func assessRecency(sleepData: [SleepData], period: DateInterval) -> Double {
        let calendar = Calendar.current
        let last7Days = calendar.date(byAdding: .day, value: -7, to: period.end) ?? period.start
        
        let recentData = sleepData.filter { data in
            data.date >= last7Days && data.date <= period.end
        }
        
        return Double(recentData.count) / 7.0
    }
    
    private func assessWeekendPattern(sleepData: [SleepData]) -> Bool {
        let calendar = Calendar.current
        var weekdayTotal: Double = 0
        var weekendTotal: Double = 0
        var weekdayCount = 0
        var weekendCount = 0
        
        for data in sleepData {
            let weekday = calendar.component(.weekday, from: data.date)
            if weekday == 1 || weekday == 7 { // Sunday or Saturday
                weekendTotal += data.durationInHours
                weekendCount += 1
            } else {
                weekdayTotal += data.durationInHours
                weekdayCount += 1
            }
        }
        
        guard weekdayCount > 0 && weekendCount > 0 else { return false }
        
        let weekdayAvg = weekdayTotal / Double(weekdayCount)
        let weekendAvg = weekendTotal / Double(weekendCount)
        
        // If weekend sleep is significantly different (30+ minutes), there's a pattern
        return abs(weekendAvg - weekdayAvg) > 0.5
    }
    
    // MARK: - Strategy Selection Logic
    
    func selectOptimalStrategy(dataQuality: DataQuality) -> MissingDataStrategy {
        if settings.adaptiveStrategy {
            return adaptiveStrategySelection(dataQuality: dataQuality)
        } else {
            return staticStrategySelection()
        }
    }
    
    private func adaptiveStrategySelection(dataQuality: DataQuality) -> MissingDataStrategy {
        // High completeness (>85%) - use interpolation for accuracy
        if dataQuality.completeness > 0.85 && dataQuality.consistency > 0.7 {
            return .interpolate
        }
        
        // Good completeness (>70%) with weekend patterns - use weekly pattern
        if dataQuality.completeness > 0.7 && dataQuality.hasWeekendPattern {
            return .useWeeklyPattern
        }
        
        // Moderate completeness (>50%) - use average
        if dataQuality.completeness > 0.5 {
            return .useAverage
        }
        
        // Poor completeness - strategy based on goal
        switch settings.primaryGoal {
        case .motivation:
            return .assumeRecommended
        case .health:
            return .conservative
        case .accuracy:
            return .useAverage
        case .balanced:
            return dataQuality.recency > 0.5 ? .useAverage : .conservative
        }
    }
    
    private func staticStrategySelection() -> MissingDataStrategy {
        switch settings.primaryGoal {
        case .motivation:
            return .assumeRecommended
        case .health:
            return .conservative
        case .accuracy:
            return .interpolate
        case .balanced:
            return .useWeeklyPattern
        }
    }
    
    // MARK: - Automated Recommendations
    
    func generateRecommendations(result: SleepDebtResult,
                                 dataQuality: DataQuality) -> [SleepRecommendation] {
        var recommendations: [SleepRecommendation] = []
        
        // Data quality recommendations
        if dataQuality.completeness < settings.dataQualityThreshold {
            recommendations.append(.improveDataCollection(
                currentRate: dataQuality.completeness,
                target: settings.dataQualityThreshold
            ))
        }
        
        // Sleep debt recommendations
        switch result.severity {
        case .minimal:
            recommendations.append(.maintain)
        case .moderate:
            recommendations.append(.gradualImprovement(debtHours: result.totalDebt))
        case .significant:
            recommendations.append(.activeRecovery(debtHours: result.totalDebt))
        case .severe:
            recommendations.append(.urgentAttention(debtHours: result.totalDebt))
        }
        
        // Pattern-based recommendations
        if dataQuality.consistency < 0.5 {
            recommendations.append(.establishRoutine)
        }
        
        if dataQuality.recency < 0.5 {
            recommendations.append(.recentTracking)
        }
        
        return recommendations
    }
    
    // MARK: - Automatic Scheduling
    
    func scheduleAutomaticCalculations(sleepData: [SleepData]) -> ScheduledCalculations {
        var scheduled: [ScheduledCalculation] = []
        
        // Daily calculation
        scheduled.append(ScheduledCalculation(
            frequency: .daily,
            period: .last7Days,
            strategy: .adaptive
        ))
        
        // Weekly summary
        if settings.weeklyRecalculation {
            scheduled.append(ScheduledCalculation(
                frequency: .weekly,
                period: .last30Days,
                strategy: .adaptive
            ))
        }
        
        // Monthly deep analysis
        scheduled.append(ScheduledCalculation(
            frequency: .monthly,
            period: .last90Days,
            strategy: .comprehensive
        ))
        
        return ScheduledCalculations(calculations: scheduled)
    }
    
    // MARK: - Helper Methods
    
    private func getDefaultPeriod() -> DateInterval {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        return DateInterval(start: startDate, end: endDate)
    }
}

// MARK: - Supporting Structures

struct DataQuality {
    let completeness: Double    // 0-1, percentage of days with data
    let consistency: Double     // 0-1, how consistent sleep patterns are
    let recency: Double         // 0-1, how much recent data is available
    let hasWeekendPattern: Bool // Whether weekends differ significantly
    let totalDays: Int
    let availableDays: Int
    
    var overallScore: Double {
        (completeness + consistency + recency) / 3.0
    }
    
    var grade: String {
        switch overallScore {
        case 0.9...1.0: return "A"
        case 0.8..<0.9: return "B"
        case 0.7..<0.8: return "C"
        case 0.6..<0.7: return "D"
        default: return "F"
        }
    }
}

struct AutomatedSleepDebtResult {
    let baseResult: SleepDebtResult
    let selectedStrategy: MissingDataStrategy
    let dataQuality: DataQuality
    let recommendations: [SleepRecommendation]
    let automationSettings: AutomatedSleepDebtCalculator.AutomationSettings
    
    var isReliable: Bool {
        dataQuality.overallScore > 0.6
    }
    
    var confidenceLevel: String {
        switch dataQuality.overallScore {
        case 0.85...1.0: return "Very High"
        case 0.7..<0.85: return "High"
        case 0.55..<0.7: return "Medium"
        case 0.4..<0.55: return "Low"
        default: return "Very Low"
        }
    }
}

enum SleepRecommendation {
    case maintain
    case gradualImprovement(debtHours: Double)
    case activeRecovery(debtHours: Double)
    case urgentAttention(debtHours: Double)
    case improveDataCollection(currentRate: Double, target: Double)
    case establishRoutine
    case recentTracking
    
    var title: String {
        switch self {
        case .maintain:
            return "Keep It Up!"
        case .gradualImprovement:
            return "Gradual Sleep Improvement"
        case .activeRecovery:
            return "Active Sleep Recovery"
        case .urgentAttention:
            return "Urgent Sleep Attention Needed"
        case .improveDataCollection:
            return "Improve Sleep Tracking"
        case .establishRoutine:
            return "Establish Sleep Routine"
        case .recentTracking:
            return "Recent Data Needed"
        }
    }
    
    var description: String {
        switch self {
        case .maintain:
            return "Your sleep debt is minimal. Continue your current habits."
        case .gradualImprovement(let debt):
            return "You have \(String(format: "%.1f", debt)) hours of sleep debt. Try going to bed 15-30 minutes earlier."
        case .activeRecovery(let debt):
            return "You have \(String(format: "%.1f", debt)) hours of sleep debt. Consider weekend recovery sleep and earlier bedtimes."
        case .urgentAttention(let debt):
            return "You have \(String(format: "%.1f", debt)) hours of sleep debt. This may impact your health. Prioritize sleep immediately."
        case .improveDataCollection(let current, let target):
            return "Only \(String(format: "%.0f%%", current * 100)) of sleep data available. Aim for \(String(format: "%.0f%%", target * 100)) for better insights."
        case .establishRoutine:
            return "Your sleep patterns are inconsistent. Try to maintain regular bedtimes and wake times."
        case .recentTracking:
            return "Recent sleep data is missing. Consistent tracking helps provide better insights."
        }
    }
}

struct ScheduledCalculation {
    enum Frequency {
        case daily, weekly, monthly
    }
    
    enum Period {
        case last7Days, last30Days, last90Days
    }
    
    enum Strategy {
        case adaptive, comprehensive, minimal
    }
    
    let frequency: Frequency
    let period: Period
    let strategy: Strategy
}

struct ScheduledCalculations {
    let calculations: [ScheduledCalculation]
}
