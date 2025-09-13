import Foundation

@MainActor
@Observable
class CalendarViewModel {

    func entriesWithWakeTimeToday(sleepData: [SleepData], day: Date) -> [SleepData] {
        let calendar = Calendar.current
        
        return sleepData.filter { data in
            calendar.isDate(data.wakeTime, inSameDayAs: day)
        }
    }
}
