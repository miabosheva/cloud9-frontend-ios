import Foundation

struct UserInfo: Codable {
    var firstName: String
    var lastName: String
    var bedtime: Date
    var wakeTime: Date
    var sleepConditions: [SleepConditions]
    var height: Int
    var weight: Int
    var autoGenerateSleepLogs: Bool = false
    
    init(
        firstName: String = "",
        lastName: String = "",
        bedtime: Date = UserInfo.defaultBedtime(),
        wakeTime: Date = UserInfo.defaultWakeTime(),
        sleepConditions: [SleepConditions] = [],
        height: Int = 0,
        weight: Int = 0,
        autoGenerateSleepLogs: Bool = false
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.sleepConditions = sleepConditions
        self.height = height
        self.weight = weight
        self.autoGenerateSleepLogs = autoGenerateSleepLogs
    }
    
    static func defaultBedtime() -> Date {
        var components = DateComponents()
        components.hour = 23   // 11 PM
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date.now
    }
    
    static func defaultWakeTime(for date: Date = Date.now) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 7  // 7 AM
        components.minute = 0
        let calendar = Calendar.current
        let todayWakeTime = calendar.date(from: components) ?? Date.now
        return calendar.date(byAdding: .day, value: 1, to: todayWakeTime) ?? todayWakeTime
    }
}

// TODO: - Define more sleep conditions
enum SleepConditions: CaseIterable, Hashable, Codable {
    case sleepApnea
    case insomnia
    
    var displayName: String {
        switch self {
        case .sleepApnea: return "Sleep Apnea"
        case .insomnia: return "Insomnia"
        }
    }
}
