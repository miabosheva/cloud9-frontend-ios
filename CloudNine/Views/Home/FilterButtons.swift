import SwiftUI

struct HeartFilterButtonsView: View {
    @Binding var selectedFilter: HeartFilter
    let onFilterChange: (HeartFilter) -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(HeartFilter.allCases, id: \.self) { filter in
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

struct SleepFilterButtonsView: View {
    @Binding var selectedFilter: SleepFilter
    let onFilterChange: (SleepFilter) -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(SleepFilter.allCases, id: \.self) { filter in
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
