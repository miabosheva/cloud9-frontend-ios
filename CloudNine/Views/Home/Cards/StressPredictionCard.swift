import SwiftUI

struct StressPredictionCard: View {
    let watchConnector: WatchConnectivityManager
    @StateObject private var collector: StressDataCollector
    
    init(watchConnector: WatchConnectivityManager) {
        self.watchConnector = watchConnector
        _collector = StateObject(wrappedValue: StressDataCollector(watchConnector: watchConnector))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Spacer()
            }
            
            if let prediction = collector.currentPrediction {
                // Show prediction result
                VStack(spacing: 12) {
                    Text("\(prediction.stressLevel)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(prediction.color)
                    
                    Text(prediction.stressCategory)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text("Stress Level")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                
            } else if collector.isCollecting {
                // Show countdown
                VStack(spacing: 12) {
                    Text("\(collector.countdown)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text("seconds remaining")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .frame(maxWidth: .infinity)
                
            } else {
                // Show start button
                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("Measure Stress")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("25 seconds")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Action button
            Button(action: {
                if collector.isCollecting {
                    collector.stopCollection()
                } else {
                    collector.startCollection()
                }
            }) {
                Text(collector.isCollecting ? "Cancel" : "Start")
            }
            .buttonStyle(PrimaryButtonStyle26Adaptive())
            .disabled(collector.isCollecting && collector.countdown == 0)
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
        .alert("Error", isPresented: .constant(collector.errorMessage != nil)) {
            Button("OK") {
                collector.errorMessage = nil
            }
        } message: {
            if let error = collector.errorMessage {
                Text(error)
            }
        }
    }
}

#Preview {
    StressPredictionCard(watchConnector: WatchConnectivityManager())
}
