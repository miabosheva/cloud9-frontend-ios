import SwiftUI

struct RealTimeHeartRateCard: View {
    let watchConnector: WatchConnectivityManager
    @Binding var showingInfoAlert: Bool
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animate ? 1.2 : 1.0)
                        .animation(
                            watchConnector.isWorkoutActive ?
                            Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                            value: animate
                        )
                }
                
                Spacer()
                
                Button {
                    showingInfoAlert.toggle()
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.gray.opacity(0.6))
                }
            }
            
            VStack(spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text("\(Int(watchConnector.currentHeartRate))")
                        .font(.title)
                        .bold()
                        .foregroundColor(colorForBPM(watchConnector.currentHeartRate))
                    
                    Text("BPM")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .offset(y: -2)
                }
                
                VStack(spacing: 4) {
                    Text("Real-time Heartrate")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Last Measured:")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Text("\(watchConnector.measurementTimestamp?.formattedDateTime ?? "N/A")")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(16)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            if watchConnector.isWorkoutActive {
                animate = true
            }
        }
        .onChange(of: watchConnector.isWorkoutActive) { _, newValue in
            animate = newValue
        }
    }
    
    func colorForBPM(_ bpm: Double) -> Color {
        switch bpm {
        case ..<40:
            return .primary
        case 40..<60:
            return .green
        case 60..<100:
            return .yellow
        default:
            return .red
        }
    }
}

#Preview {
    HealthMetricsGrid(
        healthManager: HealthManager(),
        watchConnector: WatchConnectivityManager(),
        showingSleepDebtDetails: .constant(false),
        showingInfoAlert: .constant(false)
    )
}
