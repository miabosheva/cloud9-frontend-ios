import SwiftUI
import HealthKit
import Charts

// MARK: - Supporting Views
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let iconColor: Color
    let backgroundColor: Color = .white
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct FilterButtonsView: View {
    @Binding var selectedFilter: TimeFilter
    let onFilterChange: (TimeFilter) -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(TimeFilter.allCases, id: \.self) { filter in
                Button(action: {
                    selectedFilter = filter
                    onFilterChange(filter)
                }) {
                    Text(filter.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedFilter == filter ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(selectedFilter == filter ? .white : .primary)
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
    }
}

// Fallback chart for iOS < 16
struct SimpleBarChartView: View {
    let data: [Double]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<data.count, id: \.self) { index in
                let value = data[index]
                let maxValue = data.max() ?? 1
                let height = (value / maxValue) * 180
                
                Rectangle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: max(2, 300 / CGFloat(data.count) - 4), height: height)
                    .cornerRadius(2)
            }
        }
        .padding()
    }
}
