import Foundation
import UserNotifications

/// Schedules 3–5 random stress prompts per day between 9AM and 9PM.
final class StressNotificationScheduler {
    static let shared = StressNotificationScheduler()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("❌ Notification authorization error: \(error)")
            } else {
                print("🔔 Notification permission granted: \(granted)")
            }
        }
    }

    func scheduleDailyPrompts(numberOfPrompts: Int = 4) {
        let clamped = max(3, min(numberOfPrompts, 5))

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (0..<10).map { "stress_prompt_\($0)" })

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)

        let startHour = 9
        let endHour = 21
        let totalSeconds = (endHour - startHour) * 3600

        for index in 0..<clamped {
            let offset = Int.random(in: 0..<totalSeconds)
            let hour = startHour + offset / 3600
            let minute = (offset % 3600) / 60

            var components = todayComponents
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let content = UNNotificationContent.stressPromptContent()

            let request = UNNotificationRequest(
                identifier: "stress_prompt_\(index)",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("❌ Failed to schedule stress prompt: \(error)")
                } else if let date = calendar.date(from: components) {
                    print("✅ Scheduled stress prompt at \(date)")
                }
            }
        }
    }
}

private extension UNNotificationContent {
    static func stressPromptContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Stress Check-In"
        content.body = "Take a moment to measure your current stress level."
        content.sound = .default
        content.userInfo = ["type": "stress_prompt"]
        return content
    }
}

