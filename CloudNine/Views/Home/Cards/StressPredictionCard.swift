import SwiftUI

struct StressPredictionCard: View {
    @EnvironmentObject private var stressPromptManager: StressPromptManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Stress")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(stressPromptManager.completedTodayCount)/\(stressPromptManager.dailyTarget) today")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(
                        stressPromptManager.completedTodayCount >= stressPromptManager.dailyTarget ? .green : .secondary
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            stressPromptManager.completedTodayCount >= stressPromptManager.dailyTarget
                                ? Color.green.opacity(0.12)
                                : Color.orange.opacity(0.12)
                        )
                    )
            }
            
            HStack(alignment: .center, spacing: 20) {
                if let prediction = stressPromptManager.currentPrediction {
                    HStack(spacing: 16) {
                        Text("\(prediction.stressLevel)")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(prediction.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prediction.stressCategory)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(prediction.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No measurement yet")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("25 second heart rate reading")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer(minLength: 0)
                
                Button("Measure Stress") {
                    stressPromptManager.beginMeasurement(isTest: false)
                }
                .buttonStyle(PrimaryButtonStyle26Adaptive())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    StressPredictionCard()
        .padding(.horizontal)
        .environmentObject(StressPromptManager(watchConnector: WatchConnectivityManager()))
}
