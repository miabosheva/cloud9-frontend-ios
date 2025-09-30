import SwiftUI
import Charts

// MARK: - Sleep Insights Section
struct SleepInsightsSection: View {
    let healthManager: HealthManager
    let errorManager: ErrorManager
    @Binding var sleepFilter: SleepFilter
    @State private var selectedDate: Date?
    
    private var selectedDay: SleepChartData? {
        guard let date = selectedDate else { return nil }
        return chartDataWithGaps.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundColor(.purple)
                
                Text("Sleep Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            SleepFilterButtonsView(
                selectedFilter: $sleepFilter,
                onFilterChange: { filter in
                    healthManager.loadSleepSamplesForChart(filter: sleepFilter)
                }
            )
            
            VStack(alignment: .leading, spacing: 12) {
                sleepSummary
                
                if #available(iOS 16.0, *) {
                    sleepChart
                }
                
                // Show selected day details
                if let selected = selectedDay {
                    selectedDayDetail(selected)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Sleep Summary
    private var sleepSummary: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Average Sleep")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(averageSleepText)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Goal: 8h")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(goalAchievedText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(goalAchievedColor)
            }
        }
    }
    
    // MARK: - Sleep Chart
    @available(iOS 16.0, *)
    private var sleepChart: some View {
        ZStack {
            if healthManager.sleepChartData.isEmpty {
                VStack {
                    Text("No sleep data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            } else {
                Chart(chartDataWithGaps) { data in
                    BarMark(
                        x: .value("Date", data.date, unit: .day),
                        y: .value("Hours", data.duration),
                        width: sleepFilter == .thisWeek ? 30 : 8
                    )
                    .foregroundStyle(data.duration == 0 ? AnyShapeStyle(Color.clear) : barColor(for: data.quality))
                    .cornerRadius(4)
                    .opacity(selectedDay?.id == data.id ? 0.6 : 1.0)
                    
                    RuleMark(y: .value("Target", 8))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundStyle(Color.blue.opacity(0.6))
                }
                .frame(height: 120)
                .chartYScale(domain: 0...12)
                .chartXScale(domain: xAxisDomain)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if sleepFilter == .thisWeek {
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            AxisValueLabel(format: .dateTime.day())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXSelection(value: $selectedDate)
            }
        }
    }
    
    // MARK: - Selected Day Detail
    private func selectedDayDetail(_ data: SleepChartData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.date, format: .dateTime.weekday(.wide).day().month())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(formatDuration(data.duration)) of sleep")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(data.quality)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(qualityTextColor(for: data.quality))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(qualityBackgroundColor(for: data.quality))
                .cornerRadius(6)
            
            Button(action: {
                selectedDate = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    private func barColor(for quality: String) -> AnyShapeStyle {
        switch quality {
        case "Good": return AnyShapeStyle(Color.green.gradient)
        case "Fair": return AnyShapeStyle(Color.orange.gradient)
        default: return AnyShapeStyle(Color.red.gradient)
        }
    }
    
    private func qualityTextColor(for quality: String) -> Color {
        switch quality {
        case "Good": return .green
        case "Fair": return .orange
        default: return .red
        }
    }
    
    private func qualityBackgroundColor(for quality: String) -> Color {
        switch quality {
        case "Good": return Color.green.opacity(0.15)
        case "Fair": return Color.orange.opacity(0.15)
        default: return Color.red.opacity(0.15)
        }
    }
    
    private func formatDuration(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }
    
    private var averageSleepText: String {
        let chartData = healthManager.sleepChartData
        guard !chartData.isEmpty else { return "0h 0m" }
        
        let totalHours = chartData.reduce(0.0) { $0 + $1.duration }
        let avgHours = totalHours / Double(chartData.count)
        
        return formatDuration(avgHours)
    }
    
    private var goalAchievedText: String {
        let chartData = healthManager.sleepChartData
        guard !chartData.isEmpty else { return "0% achieved" }
        
        let totalHours = chartData.reduce(0.0) { $0 + $1.duration }
        let avgHours = totalHours / Double(chartData.count)
        let percentage = Int((avgHours / 8.0) * 100)
        
        return "\(percentage)% achieved"
    }
    
    private var goalAchievedColor: Color {
        let chartData = healthManager.sleepChartData
        guard !chartData.isEmpty else { return .red }
        
        let totalHours = chartData.reduce(0.0) { $0 + $1.duration }
        let avgHours = totalHours / Double(chartData.count)
        let percentage = (avgHours / 8.0) * 100
        
        if percentage >= 90 {
            return .green
        } else if percentage >= 70 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Chart Data with Gaps
    private var chartDataWithGaps: [SleepChartData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Determine date range based on filter
        let daysBack = sleepFilter == .thisWeek ? 6 : 29
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: today) else {
            return healthManager.sleepChartData
        }
        
        // Create a dictionary of existing data by date
        let existingData = Dictionary(
            uniqueKeysWithValues: healthManager.sleepChartData.map {
                (calendar.startOfDay(for: $0.date), $0)
            }
        )
        
        // Fill in all dates in range
        var result: [SleepChartData] = []
        var currentDate = startDate
        
        while currentDate <= today {
            if let data = existingData[currentDate] {
                result.append(data)
            } else {
                // Add empty placeholder
                result.append(SleepChartData(
                    date: currentDate,
                    duration: 0,
                    quality: "None",
                    timestamp: ""
                ))
            }
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return result
    }
    
    private var xAxisDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysBack = sleepFilter == .thisWeek ? 6 : 29
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: today),
              let endDate = calendar.date(byAdding: .day, value: 1, to: today) else {
            return today...today
        }
        
        return startDate...endDate
    }
}
