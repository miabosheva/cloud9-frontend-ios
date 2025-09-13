import SwiftUI

struct CalendarView: View {
    @Environment(HealthManager.self) var healthManager
    
    @State private var currentMonth = Date.now
    @State private var selectedDate = Date.now
    @State private var days: [Date] = []
    @State private var viewModel = CalendarViewModel()
    
    let daysOfWeek = Date.capitalizedFirstLettersOfWeekdays
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var onDateSelected: (Date) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Month navigation
            HStack {
                Text(currentMonth.formatted(.dateTime.year().month()))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth)!
                    updateDays()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                Button {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)!
                    updateDays()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            
            // Days of the week row
            HStack {
                ForEach(daysOfWeek.indices, id: \.self) { index in
                    Text(daysOfWeek[index])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Grid of days
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(days, id: \.self) { day in
                    Button {
                        if day <= Date.now.startOfDay && day.monthInt <= currentMonth.monthInt {
                            selectedDate = day
                            onDateSelected(selectedDate)
                        }
                    } label: {
                        VStack {
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(foregroundStyle(for: day))
                                .frame(maxWidth: .infinity, minHeight: 40)
                            
                            ForEach(viewModel.entriesWithWakeTimeToday(sleepData: healthManager.sleepData, day: day)) { log in
                                Circle()
                                    .fill(log.qualityColor)
                                    .overlay {
                                        Text("\(log.formattedDuration)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                            }
                            .padding(4)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    day.formattedDate == selectedDate.formattedDate ? .gray : .clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .disabled(day > Date.now.startOfDay || day.monthInt > currentMonth.monthInt)
                }
            }
        }
        .padding()
        .onAppear {
            updateDays()
            onDateSelected(selectedDate)
        }
    }
    
    private func updateDays() {
        days = currentMonth.calendarDisplayDays
    }
    
    private func foregroundStyle(for day: Date) -> Color {
        let isDifferentMonth = day.monthInt != currentMonth.monthInt
        let isSelectedDate = day.formattedDate == selectedDate.formattedDate
        let isPastDate = day <= Date.now.startOfDay
        
        if isDifferentMonth {
            return isSelectedDate ? .black : .primary.opacity(0.3)
        } else if isPastDate {
            return .primary
        } else {
            return .primary.opacity(0.3)
        }
    }
}

#Preview {
    SleepCalendarView()
        .environment(HealthManager())
}
