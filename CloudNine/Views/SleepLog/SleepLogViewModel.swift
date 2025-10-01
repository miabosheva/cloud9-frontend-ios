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
    var sleepLog: SleepData?
    
    var isLoading = false
    
    private var healthManager: HealthManager
    private var geminiService = GeminiService()
    private var userManager = UserManager()
    
    var combinedBedtime: Date {
        combineDateAndTime(date: sleepDate, time: bedtime)
    }
    
    var combinedWakeTime: Date {
        let baseDate = isNextDay ? nextDay(from: sleepDate) : sleepDate
        return combineDateAndTime(date: baseDate, time: wakeTime)
    }
    
    var isTimeConfigurationValid: Bool {
        let difference = combinedWakeTime.timeIntervalSince(combinedBedtime)
        
        if isNextDay {
            return difference > 0 && difference <= 24 * 60 * 60
        } else {
            let calendar = Calendar.current
            let bedtimeDay = calendar.startOfDay(for: combinedBedtime)
            let wakeTimeDay = calendar.startOfDay(for: combinedWakeTime)
            
            return difference > 0 && bedtimeDay == wakeTimeDay
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
        
        self.sleepDate = log.date
        self.bedtime = log.bedtime
        self.wakeTime = log.wakeTime
        self.sleepQuality = log.sleepQuality ?? .fair
        self.description = log.description ?? ""
        self.sleepLog = log
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
    
    private func nextDay(from date: Date) -> Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
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
    
    func generateInsight() async throws -> String {
        defer { isLoading = false }
        do {
            isLoading = true
            let userInfo = try await userManager.fetchUserInfo()
            guard let sleepLog else { throw HealthError.failedToCreateType }
            
            let insight = try await geminiService.analyzeDream(userInfo: userInfo, sleepData: sleepLog)
            return insight
        } catch {
            throw error
        }
    }
}

extension SleepLogViewModel {
    var formattedSleepDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: sleepDate)
    }
}
