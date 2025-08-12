import SwiftUI
import HealthKit
import WatchConnectivity

struct HomeView: View {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var watchConnector = WatchConnector()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Heart Rate Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Real-Time Heart Rate")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        
                        Text("\(Int(watchConnector.currentHeartRate)) BPM")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Watch connection status
                        Image(systemName: watchConnector.isWatchConnected ? "applewatch" : "applewatch.slash")
                            .foregroundColor(watchConnector.isWatchConnected ? .green : .gray)
                    }
                    
                    HStack {
                        Button(action: {
                            watchConnector.startWorkout()
                        }) {
                            Text("Start Workout")
                                .foregroundColor(.white)
                                .padding()
                                .background(watchConnector.isWorkoutActive ? Color.gray : Color.green)
                                .cornerRadius(8)
                        }
                        .disabled(watchConnector.isWorkoutActive || !watchConnector.isWatchConnected)
                        
                        Button(action: {
                            watchConnector.stopWorkout()
                        }) {
                            Text("Stop Workout")
                                .foregroundColor(.white)
                                .padding()
                                .background(watchConnector.isWorkoutActive ? Color.red : Color.gray)
                                .cornerRadius(8)
                        }
                        .disabled(!watchConnector.isWorkoutActive)
                        
                        Spacer()
                    }
                    
                    if !watchConnector.isWatchConnected {
                        Text("Connect your Apple Watch to monitor heart rate")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Sleep Data Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sleep Data (Last 7 Days)")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    if healthManager.sleepData.isEmpty {
                        Text("No sleep data available")
                            .foregroundColor(.gray)
                            .italic()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(healthManager.sleepData, id: \.date) { sleep in
                                    SleepRowView(sleepData: sleep)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                Spacer()
                
                // Status Messages
                if !healthManager.statusMessage.isEmpty {
                    Text(healthManager.statusMessage)
                        .foregroundColor(healthManager.hasError ? .red : .green)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                if !watchConnector.statusMessage.isEmpty {
                    Text(watchConnector.statusMessage)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Health Monitor")
            .onAppear {
                healthManager.requestPermissions()
                healthManager.loadSleepData()
                watchConnector.activate()
            }
        }
    }
}
