import SwiftUI
import Charts

// MARK: - Sleep Insights Section
struct SleepInsightsSection: View {
    let healthManager: HealthManager
    let errorManager: ErrorManager
    @Binding var sleepFilter: SleepFilter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundColor(.purple)
                
                Text("Sleep Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to detailed sleep view
                }
                .font(.subheadline)
                .foregroundColor(.blue)
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
                
                Text("7h 45m")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Goal: 8h")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("97% achieved")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Sleep Chart
    @available(iOS 16.0, *)
    private var sleepChart: some View {
        Chart(healthManager.sleepChartData) { data in
            BarMark(
                x: .value("Date", data.timestamp),
                y: .value("Hours", data.duration)
            )
            .foregroundStyle(barColor(for: data.quality))
            .cornerRadius(4)
            
            RuleMark(y: .value("Target", 8))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundStyle(Color.blue.opacity(0.6))
        }
        .frame(height: 120)
        .chartYScale(domain: 0...12)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func barColor(for quality: String) -> AnyShapeStyle {
        switch quality {
        case "Good": return AnyShapeStyle(Color.green.gradient)
        case "Fair": return AnyShapeStyle(Color.orange.gradient)
        default: return AnyShapeStyle(Color.red.gradient)
        }
    }
}
