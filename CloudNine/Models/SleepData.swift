import SwiftUI

struct SleepData {
    let date: Date
    let bedtime: Date
    let wakeTime: Date
    let duration: TimeInterval
    let sessionId: String
    
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
    
    var sleepQuality: String {
        let hours = duration / 3600
        switch hours {
        case 0..<5:
            return "Poor"
        case 5..<6.5:
            return "Fair"
        case 6.5..<8.5:
            return "Good"
        default:
            return "Excellent"
        }
    }
    
    var qualityColor: Color {
        switch sleepQuality {
        case "Poor":
            return .red
        case "Fair":
            return .orange
        case "Good":
            return .green
        default:
            return .blue
        }
    }
}
