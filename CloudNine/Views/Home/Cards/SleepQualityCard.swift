import SwiftUI

struct SleepQualityCard: View {
    var duration: String
    var quality: String
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundColor(.indigo)
                
                Spacer()
                
                Text("Last Nights Sleep")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(duration)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 6) {
                Text(quality)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Sleep Quality")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
        }
        .padding(16)
        .frame(width: 180)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    SleepQualityCard(duration: "8h 0m", quality: "Good")
}
