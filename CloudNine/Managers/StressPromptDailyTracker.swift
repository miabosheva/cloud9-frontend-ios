import Foundation

/// Local persistence for daily stress prompt progress (works offline).
final class StressPromptDailyTracker {
    static let shared = StressPromptDailyTracker()
    static let dailyTarget = 4

    private let defaults = UserDefaults.standard
    private let dateKey = "stress_prompt_state_date"
    private let completedKey = "stress_prompt_completed_count"
    private let lastMeasurementKey = "stress_prompt_last_measurement"
    private let nextIndexKey = "stress_prompt_next_notification_index"

    private init() {}

    var completedTodayCount: Int {
        ensureCurrentDay()
        return defaults.integer(forKey: completedKey)
    }

    var lastMeasurementAt: Date? {
        ensureCurrentDay()
        let interval = defaults.double(forKey: lastMeasurementKey)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    @discardableResult
    func ensureCurrentDay() -> Bool {
        let today = Self.dayString(for: Date())
        let stored = defaults.string(forKey: dateKey)
        guard stored != today else { return false }

        defaults.set(today, forKey: dateKey)
        defaults.set(0, forKey: completedKey)
        defaults.removeObject(forKey: lastMeasurementKey)
        defaults.set(0, forKey: nextIndexKey)
        return true
    }

    func recordCompletion(at date: Date = Date()) {
        ensureCurrentDay()
        let updated = defaults.integer(forKey: completedKey) + 1
        defaults.set(updated, forKey: completedKey)
        defaults.set(date.timeIntervalSince1970, forKey: lastMeasurementKey)
    }

    func setCompletedCount(_ count: Int) {
        ensureCurrentDay()
        defaults.set(max(0, count), forKey: completedKey)
    }

    func nextNotificationIdentifier() -> String {
        let index = defaults.integer(forKey: nextIndexKey)
        defaults.set(index + 1, forKey: nextIndexKey)
        return "stress_prompt_\(index)"
    }

    static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
