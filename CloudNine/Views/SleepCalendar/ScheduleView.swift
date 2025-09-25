import SwiftUI

struct ScheduleView: View {
    @Environment(HealthManager.self) var healthManager
    @State private var selectedSessionDate: Date = Date.now
    
    var onDateSelected: (String) -> Void
    let calendar = Calendar.current
    
    var matchingSleepData: [SleepData] {
        return healthManager.sleepData.filter { data in
            calendar.isDate(data.date, inSameDayAs: selectedSessionDate)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                CalendarView { selectedDate in
                    self.selectedSessionDate = selectedDate
                }
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.clear)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 3)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                if matchingSleepData.count > 0 {
                    let totalSleep = (matchingSleepData.map { $0.duration }.reduce(0, +)) / 3600.0
                    let formattedSleep = totalSleep.formatted(.number.precision(.fractionLength(1)))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sleep Logs for \(selectedSessionDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Total sleep: \(formattedSleep) hours")
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        ForEach(matchingSleepData, id: \.id) { sleepData in
                            SleepLogRowView(sleepData: sleepData)
                        }
                    }
                    .padding(16)
                    
                } else {
                    VStack(alignment: .center) {
                        Text("No Sleep Logs Available for this date.")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 200)
                    .padding(32)
                    .background {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.primary.opacity(0.05))
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

#Preview {
    SleepCalendarView()
        .environment(HealthManager())
}
