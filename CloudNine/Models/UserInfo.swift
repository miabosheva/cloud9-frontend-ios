import Foundation

struct UserInfo {
    var bedtime: Date
    var wakeTime: Date
    var sleepConditions: [SleepConditions]
    var height: Int
    var weight: Int
    
    init(bedtime: Date = Date.now, wakeTime: Date = Date.now, sleepConditions: [SleepConditions] = [], height: Int = 0, weight: Int = 0) {
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.sleepConditions = sleepConditions
        self.height = height
        self.weight = weight
    }
}

// TODO: - Define more sleep conditions
enum SleepConditions: CaseIterable, Hashable {
    case sleepApnea
    case insomnia
    
    var displayName: String {
        switch self {
        case .sleepApnea: return "Sleep Apnea"
        case .insomnia: return "Insomnia"
        }
    }
}
