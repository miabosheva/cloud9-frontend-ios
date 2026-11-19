import Foundation
import UserNotifications

/// Schedules exactly 4 stress prompts per day between 9 AM and 9 PM, with makeup
/// notifications when fewer than 4 are completed.
final class StressNotificationScheduler {
    static let shared = StressNotificationScheduler()

    static let dailyTarget = StressPromptDailyTracker.dailyTarget

    private let startHour = 9
    private let endHour = 21
    private let minSpacingMinutes = 90
    private let minDelayFromNowMinutes = 30
    private let identifierPrefix = "stress_prompt_"

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

    func reconcile(completedCount: Int) async {
        _ = StressPromptDailyTracker.shared.ensureCurrentDay()

        if completedCount >= Self.dailyTarget {
            await cancelAllPrompts()
            print("✅ Daily stress target met (\(completedCount)/\(Self.dailyTarget)); cancelled pending prompts")
            return
        }

        let now = Date()
        guard let endOfWindow = endOfPromptWindow(on: now), now < endOfWindow else {
            await cancelAllPrompts()
            print("ℹ️ Past today's stress prompt window; no more prompts scheduled")
            return
        }

        let pending = await pendingStressPromptRequests()
        let futurePending = pending.compactMap { request -> (UNNotificationRequest, Date)? in
            guard let fireDate = Self.fireDate(for: request.trigger), fireDate > now else { return nil }
            return (request, fireDate)
        }
        .sorted { $0.1 < $1.1 }

        let remainingNeeded = Self.dailyTarget - completedCount
        let makeupsToSchedule = remainingNeeded - futurePending.count

        if makeupsToSchedule <= 0 {
            if futurePending.count > remainingNeeded {
                await cancelExcessPrompts(keeping: remainingNeeded, from: futurePending)
            }
            return
        }

        var scheduledTimes = futurePending.map { $0.1 }
        let additionalTimes = computeMakeupTimes(
            count: makeupsToSchedule,
            now: now,
            endOfWindow: endOfWindow,
            existingTimes: scheduledTimes,
            lastMeasurementAt: StressPromptDailyTracker.shared.lastMeasurementAt
        )

        for fireDate in additionalTimes {
            await schedulePrompt(at: fireDate)
            scheduledTimes.append(fireDate)
        }
    }

    private func computeMakeupTimes(
        count: Int,
        now: Date,
        endOfWindow: Date,
        existingTimes: [Date],
        lastMeasurementAt: Date?
    ) -> [Date] {
        guard count > 0 else { return [] }

        let calendar = Calendar.current
        var earliest = now.addingTimeInterval(TimeInterval(minDelayFromNowMinutes * 60))

        if let lastScheduled = existingTimes.max() {
            earliest = max(earliest, lastScheduled.addingTimeInterval(TimeInterval(minSpacingMinutes * 60)))
        }

        if let lastMeasurementAt {
            earliest = max(earliest, lastMeasurementAt.addingTimeInterval(TimeInterval(minSpacingMinutes * 60)))
        }

        let latest = endOfWindow.addingTimeInterval(-5 * 60)
        guard earliest <= latest else { return [] }

        var times: [Date] = []
        var candidate = earliest

        while times.count < count && candidate <= latest {
            times.append(candidate)
            candidate = calendar.date(byAdding: .minute, value: minSpacingMinutes, to: candidate)
                ?? candidate.addingTimeInterval(TimeInterval(minSpacingMinutes * 60))
        }

        return times
    }

    private func schedulePrompt(at date: Date) async {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = StressPromptDailyTracker.shared.nextNotificationIdentifier()

        let request = UNNotificationRequest(
            identifier: identifier,
            content: .stressPromptContent(),
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled stress prompt at \(date) (\(identifier))")
        } catch {
            print("❌ Failed to schedule stress prompt: \(error)")
        }
    }

    private func endOfPromptWindow(on date: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = endHour
        components.minute = 0
        return calendar.date(from: components)
    }

    private func pendingStressPromptRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.filter { $0.identifier.hasPrefix(self.identifierPrefix) })
            }
        }
    }

    private func cancelAllPrompts() async {
        let pending = await pendingStressPromptRequests()
        let identifiers = pending.map(\.identifier)
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func cancelExcessPrompts(keeping count: Int, from futurePending: [(UNNotificationRequest, Date)]) async {
        guard futurePending.count > count else { return }
        let excess = futurePending.dropFirst(count).map { $0.0.identifier }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: excess)
    }

    /// Resolves the next fire date for calendar-based stress prompts.
    private static func fireDate(for trigger: UNNotificationTrigger?) -> Date? {
        guard let calendarTrigger = trigger as? UNCalendarNotificationTrigger else { return nil }
        return calendarTrigger.nextTriggerDate()
    }
}

private extension UNNotificationContent {
    static func stressPromptContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Stress Check-In"
        content.body = "Wear your Apple Watch and tap to measure stress."
        content.sound = .default
        content.userInfo = ["type": "stress_prompt"]
        return content
    }
}
