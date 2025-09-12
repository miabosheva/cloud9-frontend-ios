import Foundation

extension HealthManager {
    /// Combines a date with a time from another Date
    func combine(date: Date, time: Date) -> Date {
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
    
    // MARK: - Heart Filter
    func dateRange(for filter: HeartFilter) -> (Date, Date) {
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
    
    // MARK: - Sleep Filter
    func dateRange(for filter: SleepFilter) -> (Date, Date) {
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
    
    func formatTimestamp(_ date: Date, for filter: HeartFilter) -> String {
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
    
    func formatTimestamp(_ date: Date, for filter: SleepFilter) -> String {
        let formatter = DateFormatter()
        switch filter {
        case .thisWeek:
            formatter.dateFormat = "EEE"
        case .thisMonth:
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
    
    // MARK: - Enhanced Overlap Detection
    func validateNoOverlap(bedtime: Date, wakeTime: Date) async throws {
        for existing in sleepData {
            if hasTimeOverlap(
                start1: bedtime, end1: wakeTime,
                start2: existing.bedtime, end2: existing.wakeTime
            ) {
                if existing.savedFlag == false {
                    try await deleteSleepSession(existing)
                } else {
                    throw HealthError.sleepLogOverlaps
                }
            }
        }
    }
    
    func hasTimeOverlap(start1: Date, end1: Date, start2: Date, end2: Date) -> Bool {
        // Two time ranges overlap if:
        // start1 < end2 AND start2 < end1
        return start1 < end2 && start2 < end1
    }
}
