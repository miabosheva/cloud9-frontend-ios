import SwiftUI

struct SleepCalendarView: View {
    var body: some View {
        ScheduleView { date in
            print("\(date)")
        }
        .navigationTitle("Sleep Logs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SleepCalendarView()
}
