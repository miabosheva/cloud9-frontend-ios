import SwiftUI

struct ScheduleView: View {
    @State private var selectedSessionDate: Date = Date.now
    
    var onDateSelected: (String) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            CalendarView { selectedDate in
                self.selectedSessionDate = selectedDate
            }
            
            HStack {
                Spacer()
                Button {
                    onDateSelected(selectedSessionDate.formattedDateHourCombined)
                } label: {
                    Image(systemName: "checkmark")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.blue)
                        .padding()
                        .background(
                            Circle()
                                .stroke(.blue, lineWidth: 2)
                                .fill(.blue.opacity(0.1))
                        )
                }
            }
            Spacer()
        }
    }
}

#Preview {
    SleepCalendarView()
}
