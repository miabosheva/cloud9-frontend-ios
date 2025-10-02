import SwiftUI
import HealthKit
import WatchConnectivity

struct WatchContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some View {
        TabView {
            // Page 1: Heart Rate Monitor
            HeartRateView(workoutManager: workoutManager)
                .containerBackground(.black, for: .tabView)
            
            // Page 2: Sleep Debt
            WatchSleepDebtCard(sleepData: workoutManager.sleepDebtData)
                .containerBackground(.black, for: .tabView)
            
            // Page 3: Sleep Quality
            WatchSleepQualityCard(sleepData: workoutManager.sleepQualityData)
                .containerBackground(.black, for: .tabView)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .automatic))
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

// MARK: - Heart Rate View (Original Screen)
struct HeartRateView: View {
    @ObservedObject var workoutManager: WorkoutManager
    
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
                Button("Start Measuring") {
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
    }
}

// MARK: - Watch Sleep Debt Card
struct WatchSleepDebtCard: View {
    let sleepData: SleepDebtData?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: sleepData?.severityIcon ?? "moon.fill")
                        .font(.title2)
                        .foregroundColor(sleepData?.severityColor ?? .blue)
                    
                    Spacer()
                    
                    if let grade = sleepData?.dataQualityGrade {
                        Text(grade)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(sleepData?.dataQualityColor ?? .gray)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sleep Debt")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(sleepData?.totalDebt ?? "No Data")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if let severity = sleepData?.severity {
                        Text(severity.lowercased())
                            .font(.caption2)
                            .foregroundColor(sleepData?.severityColor ?? .gray)
                    }
                }
                
                if let efficiency = sleepData?.efficiency {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Efficiency")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(efficiency)%")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        
                        ProgressView(value: Double(efficiency) / 100.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: sleepData?.efficiencyColor ?? .blue))
                    }
                }
                
                if let missingDays = sleepData?.missingDaysCount, missingDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text("\(missingDays) missing days")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Watch Sleep Quality Card
struct WatchSleepQualityCard: View {
    let sleepData: SleepQualityData?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundColor(.indigo)
                
                Spacer()
                
                Text("Last Night")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let duration = sleepData?.duration, let quality = sleepData?.quality {
                Text(duration)
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 4) {
                    Text(quality)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Sleep Quality")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No Entry Yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            }
        }
        .padding()
    }
}

// MARK: - Data Models
struct SleepDebtData {
    let totalDebt: String
    let severity: String
    let severityIcon: String
    let severityColor: Color
    let efficiency: Int
    let efficiencyColor: Color
    let dataQualityGrade: String
    let dataQualityColor: Color
    let missingDaysCount: Int
}

struct SleepQualityData {
    let duration: String
    let quality: String
}
