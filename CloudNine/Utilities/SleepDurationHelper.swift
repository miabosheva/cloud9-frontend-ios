import Foundation

class SleepDurationHelper {
    static func calculateSleepDuration(bedtime: Date, wakeTime: Date) -> String {
        let calendar = Calendar.current
        
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: bedtime)
        let wakeTimeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        
        // Convert to minutes for easier calculation
        let bedtimeMinutes = (bedtimeComponents.hour ?? 0) * 60 + (bedtimeComponents.minute ?? 0)
        let wakeTimeMinutes = (wakeTimeComponents.hour ?? 0) * 60 + (wakeTimeComponents.minute ?? 0)
        
        // Calculate duration, accounting for crossing midnight
        var durationMinutes = wakeTimeMinutes - bedtimeMinutes
        if durationMinutes <= 0 {
            durationMinutes += 24 * 60 // Add 24 hours if crossing midnight
        }
        
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        
        if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}
