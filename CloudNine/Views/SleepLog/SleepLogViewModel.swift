import Foundation

@MainActor
@Observable
class SleepLogViewModel {
    var sleepDate = Date()
    var bedtime = Date()
    var wakeTime = Date()
    var sleepQuality: SleepQuality = .fair
    var description: String = ""
    var isNextDay: Bool = true
    
    private var healthManager: HealthManager
    
    var combinedBedtime: Date {
        combineDateAndTime(date: sleepDate, time: bedtime)
    }
    
    var combinedWakeTime: Date {
        let baseDate = shouldUseNextDay(for: wakeTime) ? nextDay(from: sleepDate) : sleepDate
        return combineDateAndTime(date: baseDate, time: wakeTime)
    }
    
    var isTimeConfigurationValid: Bool {
        let bedtimeHour = Calendar.current.component(.hour, from: bedtime)
        let wakeTimeHour = Calendar.current.component(.hour, from: wakeTime)
        
        if isNextDay {
            // Wake time should be earlier in the day than bedtime for next-day scenario
            // OR bedtime is late (after 6 PM) and wake time is early (before noon)
            return bedtimeHour >= 18 || wakeTimeHour <= 12
        } else {
            // Same day: wake time should be after bedtime
            return wakeTimeHour > bedtimeHour
        }
    }
    
    init(healthManager: HealthManager) {
        self.healthManager = healthManager
    }
    
    func loadSleepLog(by id: String, sleepData: [SleepData]) throws {
        guard let log = sleepData.first(where: {$0.id == id}) else {
            try setupDefaultTimes()
            return
        }
        
        // Set all properties to match the sleep log
        self.sleepDate = log.date
        self.bedtime = log.bedtime
        self.wakeTime = log.wakeTime
        self.sleepQuality = log.sleepQuality ?? .fair
        self.description = log.description ?? ""
        
        self.isNextDay = determineIfNextDay(bedtime: log.bedtime, wakeTime: log.wakeTime)
    }
    
    func validateAndAdjustTimes() {
        // Called when user manually changes times or isNextDay toggle
        let bedtimeHour = Calendar.current.component(.hour, from: bedtime)
        let wakeTimeHour = Calendar.current.component(.hour, from: wakeTime)
        
        // If the configuration doesn't make logical sense, suggest the correct isNextDay setting
        if !isTimeConfigurationValid {
            // Auto-correct based on what makes more sense
            if bedtimeHour >= 20 || bedtimeHour <= 6 { // Late night or very early bedtime
                if wakeTimeHour >= 5 && wakeTimeHour <= 11 { // Morning wake time
                    isNextDay = true
                }
            } else if bedtimeHour >= 6 && bedtimeHour <= 20 { // Daytime bedtime
                if wakeTimeHour > bedtimeHour { // Wake time later same day
                    isNextDay = false
                }
            }
        }
    }
    
    private func determineIfNextDay(bedtime: Date, wakeTime: Date) -> Bool {
        let calendar = Calendar.current
        let bedtimeHour = calendar.component(.hour, from: bedtime)
        let wakeTimeHour = calendar.component(.hour, from: wakeTime)
        
        // If bedtime is late (after 6 PM) and wake time is early (before noon), likely next day
        // OR if wake time hour is less than bedtime hour, it's likely next day
        return (bedtimeHour >= 18 && wakeTimeHour <= 12) || wakeTimeHour < bedtimeHour
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
        // Don't modify the time components, just update the date logic
        // The times stay the same, but we recalculate which dates they should be on
        
        // Auto-adjust isNextDay based on current time settings if they seem illogical
        let bedtimeHour = Calendar.current.component(.hour, from: bedtime)
        let wakeTimeHour = Calendar.current.component(.hour, from: wakeTime)
        
        // Smart auto-adjustment: if current setting doesn't make sense, fix it
        if !isTimeConfigurationValid {
            isNextDay = determineIfNextDay(bedtime: bedtime, wakeTime: wakeTime)
        }
    }
    
    func setupDefaultTimes() throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Default to last night
        sleepDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        
        let userInfoPerssisted = try? healthManager.fetchLocalUserInfo()
        let userPreference = userInfoPerssisted ?? UserInfo()
        
        bedtime = userPreference.bedtime
        wakeTime = userPreference.wakeTime
        
        // Determine if this should be next day based on user preferences
        isNextDay = determineIfNextDay(bedtime: bedtime, wakeTime: wakeTime)
        
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
