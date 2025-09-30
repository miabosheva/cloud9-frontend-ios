import SwiftUI
import Charts

struct HeartRateSection: View {
    let healthManager: HealthManager
    let errorManager: ErrorManager
    let watchConnector: WatchConnector
    @Binding var heartRateFilter: HeartFilter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                
                Text("Heart Rate Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HeartFilterButtonsView(
                selectedFilter: $heartRateFilter,
                onFilterChange: { filter in
                    Task {
                        do {
                            try await healthManager.loadHeartRateData(for: filter)
                        } catch {
                            errorManager.handle(error: error)
                        }
                    }
                }
            )
            
            heartRateSummary
            
            if #available(iOS 16.0, *) {
                heartRateChart
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Heart Rate Summary
    private var heartRateSummary: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading) {
                Text("Current")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(watchConnector.currentHeartRate)) BPM")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading) {
                Text("Average")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("72 BPM")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Range")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("58-95 BPM")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Heart Rate Chart
    @available(iOS 16.0, *)
    private var heartRateChart: some View {
        Chart(healthManager.heartRateData) { data in
            LineMark(
                x: .value("Time", data.timestamp),
                y: .value("Heart Rate", data.heartRate)
            )
            .foregroundStyle(Color.red.gradient)
            .lineStyle(.init(lineWidth: 2))
            
            AreaMark(
                x: .value("Time", data.timestamp),
                y: .value("Heart Rate", data.heartRate)
            )
            .foregroundStyle(Color.red.opacity(0.1).gradient)
        }
        .frame(height: 120)
        .chartYScale(domain: 40...120)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel(format: .dateTime.hour())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
