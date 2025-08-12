import SwiftUI
import HealthKit
import WatchConnectivity

struct WatchContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some View {
        VStack(spacing: 15) {
            // Heart Rate Display
            VStack {
                Text("Heart Rate")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    
                    Text("\(Int(workoutManager.heartRate))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Workout Controls
            if workoutManager.running {
                Button("Stop") {
                    workoutManager.endWorkout()
                }
                .foregroundColor(.red)
            } else {
                Button("Start Workout") {
                    workoutManager.startWorkout()
                }
                .foregroundColor(.green)
            }
            
            // Status
            if !workoutManager.statusMessage.isEmpty {
                Text(workoutManager.statusMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}
