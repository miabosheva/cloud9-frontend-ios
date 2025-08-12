import SwiftUI

struct SleepRowView: View {
    let sleepData: SleepData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sleepData.date, style: .date)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(.blue)
                
                Text("Duration: \(sleepData.formattedDuration)")
                    .font(.caption)
                
                Spacer()
                
                Text("\(sleepData.formattedBedtime) - \(sleepData.formattedWakeTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.8))
        .cornerRadius(6)
    }
}
