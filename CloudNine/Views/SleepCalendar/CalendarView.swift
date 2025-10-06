import SwiftUI

struct CalendarView: View {
    @Environment(HealthManager.self) var healthManager
    
    @State private var currentMonth = Date.now
    @State private var selectedDate = Date.now
    @State private var days: [Date] = []
    @State private var viewModel = CalendarViewModel()
    @State private var rowHeights: [Int: CGFloat] = [:]
    
    let daysOfWeek = Date.capitalizedFirstLettersOfWeekdays
    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 7)
    
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
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let rowIndex = index / 7
                    let entries = viewModel.entriesFromDate(sleepData: healthManager.sleepData, day: day)
                    
                    DayCell(
                        day: day,
                        currentMonth: currentMonth,
                        selectedDate: selectedDate,
                        entries: entries,
                        rowHeight: rowHeights[rowIndex],
                        onTap: {
                            if day <= Date.now.startOfDay && day.monthInt <= currentMonth.monthInt {
                                selectedDate = day
                                onDateSelected(selectedDate)
                            }
                        }
                    )
                    .onAppear {
                        updateRowHeight(for: rowIndex, entries: entries)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            updateDays()
            onDateSelected(selectedDate)
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 3)
        }
    }
    
    private func updateDays() {
        days = currentMonth.calendarDisplayDays
        recalculateAllRowHeights()
    }
    
    private func updateRowHeight(for rowIndex: Int, entries: [SleepData]) {
        let calculatedHeight = calculateCellHeight(for: entries.count)
        
        if let currentHeight = rowHeights[rowIndex] {
            rowHeights[rowIndex] = max(currentHeight, calculatedHeight)
        } else {
            rowHeights[rowIndex] = calculatedHeight
        }
    }
    
    private func recalculateAllRowHeights() {
        rowHeights.removeAll()
        
        for (index, day) in days.enumerated() {
            let rowIndex = index / 7
            let entries = viewModel.entriesFromDate(sleepData: healthManager.sleepData, day: day)
            updateRowHeight(for: rowIndex, entries: entries)
        }
    }
    
    private func calculateCellHeight(for entryCount: Int) -> CGFloat {
        let baseHeight: CGFloat = 48
        let circleHeight: CGFloat = 30
        let spacing: CGFloat = 4
        let bottomPadding: CGFloat = 8
        
        if entryCount == 0 {
            return baseHeight
        }
        
        let entriesHeight = CGFloat(entryCount) * circleHeight + CGFloat(entryCount - 1) * spacing
        return baseHeight + entriesHeight + spacing + bottomPadding
    }
}

// MARK: - Day Cell Component
struct DayCell: View {
    let day: Date
    let currentMonth: Date
    let selectedDate: Date
    let entries: [SleepData]
    let rowHeight: CGFloat?
    let onTap: () -> Void
    
    private var isDisabled: Bool {
        day > Date.now.startOfDay || day.monthInt > currentMonth.monthInt
    }
    
    private var foregroundColor: Color {
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
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(foregroundColor)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                
                if !entries.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(entries) { log in
                            Circle()
                                .fill(log.qualityColor)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Text("\(log.formattedDuration)")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: rowHeight ?? 48, maxHeight: rowHeight ?? .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                day.formattedDate == selectedDate.formattedDate ? Color.accentColor : .clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview {
    SleepCalendarView()
        .environment(HealthManager())
}
