import SwiftUI

struct TemperatureCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Text("°F")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 6) {
                Text("98.6")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Normal")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            
            Text("Body Temperature")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(width: 180)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Sleep Quality Card
struct SleepQualityCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundColor(.indigo)
                
                Spacer()
                
                Text("Last Night")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 6) {
                Text("Good")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("7h 23m")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Text("Sleep Quality")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 180)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
