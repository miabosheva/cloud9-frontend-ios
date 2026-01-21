import SwiftUI
import Charts

struct StepsSection: View {
    let healthManager: HealthManager
    let errorManager: ErrorManager
    @Binding var stepsFilter: StepsFilter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(.green)
                
                Text("Step Count")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            StepsFilterButtonsView(
                selectedFilter: $stepsFilter,
                onFilterChange: { filter in
                    Task {
                        do {
                            try await healthManager.loadStepsData(for: filter)
                        } catch {
                            errorManager.handle(error: error)
                        }
                    }
                }
            )
            
            stepsSummary
            
            if #available(iOS 16.0, *) {
                stepsChart
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Steps Summary
    private var stepsSummary: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading) {
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(todaySteps)")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            // Only show average for week and month filters
            if stepsFilter != .today {
                VStack(alignment: .leading) {
                    Text("Average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(averageSteps)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Goal: 10,000")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(goalPercentage)%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(goalColor)
            }
        }
    }
    
    // MARK: - Steps Chart
    @available(iOS 16.0, *)
    private var stepsChart: some View {
        ZStack {
            if healthManager.stepsData.isEmpty {
                VStack {
                    Text("No step data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            } else {
                Chart(healthManager.stepsData) { data in
                    BarMark(
                        x: .value("Date", data.date, unit: stepsFilter == .today ? .hour : .day),
                        y: .value("Steps", data.steps),
                        width: stepsFilter == .today ? 20 : (stepsFilter == .thisWeek ? 30 : 8)
                    )
                    .foregroundStyle(Color.green.gradient)
                    .cornerRadius(4)
                    
                    RuleMark(y: .value("Goal", 10000))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundStyle(Color.blue.opacity(0.6))
                }
                .frame(height: 120)
                .chartYScale(domain: 0...maxSteps)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        if stepsFilter == .today {
                            AxisValueLabel(format: .dateTime.hour())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if stepsFilter == .thisWeek {
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
            }
        }
    }
    
    // MARK: - Helper Computed Properties
    private var todaySteps: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Sum all steps for today (could be multiple entries if grouped by hour)
        let todayTotal = healthManager.stepsData
            .filter { calendar.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + $1.steps }
        
        return formatSteps(todayTotal)
    }
    
    private var averageSteps: String {
        guard !healthManager.stepsData.isEmpty else { return "0" }
        
        let total = healthManager.stepsData.reduce(0) { $0 + $1.steps }
        let average = total / healthManager.stepsData.count
        return formatSteps(average)
    }
    
    private var goalPercentage: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Sum all steps for today (could be multiple entries if grouped by hour)
        let todayStepCount = healthManager.stepsData
            .filter { calendar.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + $1.steps }
        
        return Int((Double(todayStepCount) / 10000.0) * 100)
    }
    
    private var goalColor: Color {
        let percentage = goalPercentage
        if percentage >= 100 {
            return .green
        } else if percentage >= 70 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var maxSteps: Int {
        let maxSteps = healthManager.stepsData.map { $0.steps }.max() ?? 10000
        // Round up to nearest 5000 for better chart display
        return max((maxSteps / 5000 + 1) * 5000, 10000)
    }
    
    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            let thousands = Double(steps) / 1000.0
            return String(format: "%.1fK", thousands)
        }
        return "\(steps)"
    }
}
