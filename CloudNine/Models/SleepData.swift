import SwiftUI

enum SleepQuality: String, CaseIterable, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case terrible = "Terrible"
    
    var numericValue: Double {
        switch self {
        case .excellent: return 5.0
        case .good: return 4.0
        case .fair: return 3.0
        case .poor: return 2.0
        case .terrible: return 1.0
        }
    }
}

struct SleepData: Identifiable, Codable {
    var id: String
    var date: Date
    var bedtime: Date
    var wakeTime: Date
    var duration: TimeInterval
    var sleepQuality: SleepQuality?
    var description: String?
    var savedFlag: Bool = false
    
    var tags: [String] = []
    var isLocalOnly: Bool = false
    var lastSyncedAt: Date?
    var needsSync: Bool = false
    
    init(date: Date, bedtime: Date, wakeTime: Date, duration: TimeInterval, savedFlag: Bool, sleepQuality: SleepQuality? = nil, description: String? = nil) {
        self.id = "\(bedtime.timeIntervalSince1970)-\(Int.random(in: 1000...9999))"
        self.date = date
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.duration = duration
        self.savedFlag = savedFlag
        self.sleepQuality = sleepQuality
        self.description = description
        self.needsSync = sleepQuality != nil || description != nil
    }
    
    var hasMetadata: Bool {
        return sleepQuality != nil || description != nil || !tags.isEmpty
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
    
    var formattedBedtime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: bedtime)
    }
    
    var formattedWakeTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: wakeTime)
    }
    
    var qualityColor: Color {
        switch sleepQuality {
        case .excellent:
            Color.green
        case .good:
            Color.yellow
        case .fair:
            Color.blue
        case .poor:
            Color.red
        case .terrible:
            Color.black
        case nil:
            Color.blue
        }
    }
}
