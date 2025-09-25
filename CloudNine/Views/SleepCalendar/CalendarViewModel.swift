import Foundation

@MainActor
@Observable
class CalendarViewModel {

    func entriesFromDate(sleepData: [SleepData], day: Date) -> [SleepData] {
        let calendar = Calendar.current
        
        return sleepData.filter { data in
            calendar.isDate(data.date, inSameDayAs: day)
        }
    }
}
