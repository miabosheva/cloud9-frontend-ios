import SwiftUI
import Foundation

// Sleep debt calculator
class SleepDebtCalculator {
    // Recommended sleep hours (can be customized per user)
    private let recommendedSleepHours: Double
    
    init(recommendedSleepHours: Double = 8.0) {
        self.recommendedSleepHours = recommendedSleepHours
    }
    
    // Calculate sleep debt for a single night
    func calculateNightlyDebt(for sleepData: SleepData) -> Double {
        return max(0, recommendedSleepHours - sleepData.durationInHours)
    }
    
    // Calculate cumulative sleep debt over a period
    func calculateCumulativeDebt(sleepData: [SleepData],
                                startDate: Date,
                                endDate: Date) -> SleepDebtResult {
        
        let calendar = Calendar.current
        
        // Get all dates in the range
        var allDates: [Date] = []
        var currentDate = startDate
        while currentDate <= endDate {
            allDates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Filter sleep data for the date range
        let relevantSleepData = sleepData.filter { data in
            let sleepDate = calendar.startOfDay(for: data.date)
            return sleepDate >= calendar.startOfDay(for: startDate) &&
                   sleepDate <= calendar.startOfDay(for: endDate)
        }
        
        // Create a dictionary for quick lookup
        let sleepDataDict = Dictionary(grouping: relevantSleepData) { data in
            calendar.startOfDay(for: data.date)
        }
        
        var totalDebt: Double = 0
        var totalActualSleep: Double = 0
        var totalRecommendedSleep: Double = 0
        var missingDays: [Date] = []
        var dailyDebts: [Date: Double] = [:]
        
        for date in allDates {
            let dayStart = calendar.startOfDay(for: date)
            totalRecommendedSleep += recommendedSleepHours
            
            if let dayData = sleepDataDict[dayStart]?.first {
                // We have data for this day
                let actualSleep = dayData.durationInHours
                let dailyDebt = max(0, recommendedSleepHours - actualSleep)
                
                totalActualSleep += actualSleep
                totalDebt += dailyDebt
                dailyDebts[dayStart] = dailyDebt
            } else {
                // Missing data - assume no sleep (worst case) or use estimation
                missingDays.append(date)
                let estimatedDebt = handleMissingEntry(for: date,
                                                    availableData: relevantSleepData,
                                                       strategy: .useWeeklyPattern)
                totalDebt += estimatedDebt
                dailyDebts[dayStart] = estimatedDebt
            }
        }
        
        return SleepDebtResult(
            totalDebt: totalDebt,
            averageDebtPerNight: totalDebt / Double(allDates.count),
            totalActualSleep: totalActualSleep,
            totalRecommendedSleep: totalRecommendedSleep,
            missingDays: missingDays,
            dailyDebts: dailyDebts,
            period: DateInterval(start: startDate, end: endDate)
        )
    }
    
    // Handle missing sleep entries with different strategies
    func handleMissingEntry(for date: Date,
                           availableData: [SleepData],
                           strategy: MissingDataStrategy) -> Double {
        switch strategy {
        case .assumeRecommended:
            // Optimistic: assume they got recommended sleep
            return 0
            
        case .useAverage:
            // Use average of available data
            guard !availableData.isEmpty else { return recommendedSleepHours }
            let averageSleep = availableData.map { $0.durationInHours }.reduce(0, +) / Double(availableData.count)
            return max(0, recommendedSleepHours - averageSleep)
            
        case .useWeeklyPattern:
            // Use same day of week average
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date)
            let sameDayData = availableData.filter {
                calendar.component(.weekday, from: $0.date) == weekday
            }
            
            if sameDayData.isEmpty {
                return handleMissingEntry(for: date, availableData: availableData, strategy: .useAverage)
            }
            
            let averageSameDaySleep = sameDayData.map { $0.durationInHours }.reduce(0, +) / Double(sameDayData.count)
            return max(0, recommendedSleepHours - averageSameDaySleep)
            
        case .conservative:
            // Pessimistic: assume they got less sleep, adding full recommended hours as debt
            return recommendedSleepHours
            
        case .interpolate:
            // Linear interpolation between surrounding days
            return interpolateMissingDay(for: date, availableData: availableData)
        }
    }
    
    private func interpolateMissingDay(for date: Date, availableData: [SleepData]) -> Double {
        let sortedData = availableData.sorted { $0.date < $1.date }
        
        // Find the closest days before and after
        var before: SleepData?
        var after: SleepData?
        
        for data in sortedData {
            if data.date < date {
                before = data
            } else if data.date > date && after == nil {
                after = data
                break
            }
        }
        
        let estimatedSleep: Double
        
        switch (before, after) {
        case let (beforeData?, afterData?):
            // Interpolate between the two
            let timeDiff = afterData.date.timeIntervalSince(beforeData.date)
            let targetDiff = date.timeIntervalSince(beforeData.date)
            let ratio = targetDiff / timeDiff
            
            estimatedSleep = beforeData.durationInHours +
                           (afterData.durationInHours - beforeData.durationInHours) * ratio
            
        case let (beforeData?, nil):
            // Use the last known value
            estimatedSleep = beforeData.durationInHours
            
        case let (nil, afterData?):
            // Use the next known value
            estimatedSleep = afterData.durationInHours
            
        case (nil, nil):
            // No data available, use recommended sleep
            estimatedSleep = recommendedSleepHours
        }
        
        return max(0, recommendedSleepHours - estimatedSleep)
    }
    
    // Calculate recovery time needed
    func calculateRecoveryTime(currentDebt: Double,
                              dailyRecoveryRate: Double = 1.0) -> Int {
        guard currentDebt > 0 else { return 0 }
        return Int(ceil(currentDebt / dailyRecoveryRate))
    }
}

// Strategies for handling missing data
enum MissingDataStrategy {
    case assumeRecommended  // Assume they got recommended sleep (optimistic)
    case useAverage        // Use average of available data
    case useWeeklyPattern  // Use average for same day of week
    case conservative      // Assume no sleep (pessimistic)
    case interpolate       // Linear interpolation
}

// Result structure
struct SleepDebtResult {
    let totalDebt: Double
    let averageDebtPerNight: Double
    let totalActualSleep: Double
    let totalRecommendedSleep: Double
    let missingDays: [Date]
    let dailyDebts: [Date: Double]
    let period: DateInterval
    
    var efficiency: Double {
        guard totalRecommendedSleep > 0 else { return 0 }
        return (totalActualSleep / totalRecommendedSleep) * 100
    }
    
    var formattedTotalDebt: String {
        let hours = Int(totalDebt)
        let minutes = Int((totalDebt - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }
    
    var severity: DebtSeverity {
        switch totalDebt {
        case 0..<5:
            return .minimal
        case 5..<15:
            return .moderate
        case 15..<30:
            return .significant
        default:
            return .severe
        }
    }
}

enum DebtSeverity: String {
    case minimal = "Minimal"
    case moderate = "Moderate"
    case significant = "Significant"
    case severe = "Severe"
    
    var color: Color {
        switch self {
        case .minimal: return .green
        case .moderate: return .yellow
        case .significant: return .orange
        case .severe: return .red
        }
    }
}

// Usage example
extension SleepDebtCalculator {
    func getWeeklyDebt(sleepData: [SleepData]) -> SleepDebtResult {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        
        return calculateCumulativeDebt(
            sleepData: sleepData,
            startDate: startDate,
            endDate: endDate
        )
    }
    
    func getMonthlyDebt(sleepData: [SleepData]) -> SleepDebtResult {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        
        return calculateCumulativeDebt(
            sleepData: sleepData,
            startDate: startDate,
            endDate: endDate
        )
    }
}
