import Foundation

@Observable
class SleepLogViewModel {
    var sleepDate = Date()
    var bedtime = Date()
    var wakeTime = Date()
    var sleepQuality: SleepQuality = .fair
    var description: String = ""
    var isNextDay: Bool = true
    
    var combinedBedtime: Date {
        combineDateAndTime(date: sleepDate, time: bedtime)
    }
    
    var combinedWakeTime: Date {
        let baseDate = shouldUseNextDay(for: wakeTime) ? nextDay(from: sleepDate) : sleepDate
        return combineDateAndTime(date: baseDate, time: wakeTime)
    }
    
    func loadSleepLog(by id: String, sleepData: [SleepData]) {
        guard let log = sleepData.first(where: {$0.id == id}) else {
            setupDefaultTimes()
            return
        }
        
        // Set all properties to match the sleep log
        self.sleepDate = log.date
        self.bedtime = log.bedtime
        self.wakeTime = log.wakeTime
        self.sleepQuality = log.sleepQuality ?? .fair
        self.description = log.description ?? ""
    }
    
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = 0
        
        return calendar.date(from: combined) ?? date
    }
    
    private func shouldUseNextDay(for time: Date) -> Bool {
        let calendar = Calendar.current
        let timeHour = calendar.component(.hour, from: time)
        let bedtimeHour = calendar.component(.hour, from: bedtime)
        
        // If wake time is earlier in the day than bedtime, it's probably next day
        return timeHour < bedtimeHour || timeHour < 12 // Assuming wake times before noon are next day
    }
    
    private func nextDay(from date: Date) -> Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
    }
    
    func updateTimesWithNewDate() {
        // When sleep date changes, update the time pickers to maintain the same time
        // but with the new date
        bedtime = combineDateAndTime(date: sleepDate, time: bedtime)
        
        // For wake times, determine if they should be next day
        let nextDayDate = nextDay(from: sleepDate)
        wakeTime = combineDateAndTime(date: isNextDay ? nextDayDate : sleepDate, time: wakeTime)
    }
    
    func setupDefaultTimes() {
        let calendar = Calendar.current
        let now = Date()
        
        // Default to last night
        sleepDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        
        // Set default times - these will be combined with sleepDate later
        let defaultBedtimeComponents = DateComponents(hour: 22, minute: 30)
        let defaultWakeTimeComponents = DateComponents(hour: 7, minute: 0)
        
        bedtime = calendar.date(from: defaultBedtimeComponents) ?? now
        wakeTime = calendar.date(from: defaultWakeTimeComponents) ?? now
        
        // Now update with the correct dates
        updateTimesWithNewDate()
    }
    
    func formatSleepDuration() -> String {
        let duration = combinedWakeTime.timeIntervalSince(combinedBedtime)
        
        let hours = Int(abs(duration)) / 3600
        let minutes = Int(abs(duration)) % 3600 / 60
        
        return "\(hours)h \(minutes)m"
    }
    
    func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension SleepLogViewModel {
    var formattedSleepDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy" // Example: Monday, Aug 31, 2025
        return formatter.string(from: sleepDate)
    }
}
