import SwiftUI
import HealthKit
import WatchConnectivity

struct WatchContentView: View {
    @StateObject private var workoutManager = WorkoutManager()

    var body: some View {
        TabView {
            WatchHeartRatePage(workoutManager: workoutManager)
                .containerBackground(.black, for: .tabView)

            WatchSleepDebtCard(sleepData: workoutManager.sleepDebtData)
                .containerBackground(.black, for: .tabView)

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

// MARK: - Heart Rate Page (real-time HR vs stress measurement loader)

struct WatchHeartRatePage: View {
    @ObservedObject var workoutManager: WorkoutManager

    var body: some View {
        Group {
            if workoutManager.isStressMeasurementActive {
                WatchStressMeasurementView()
            } else {
                WatchRealTimeHeartRateView(workoutManager: workoutManager)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: workoutManager.isStressMeasurementActive)
    }
}

// MARK: - Real-time heart rate (passive display — started from iPhone only for stress)

struct WatchRealTimeHeartRateView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Heart Rate")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                    .scaleEffect(pulse ? 1.5 : 1.7)
                    .animation(
                        workoutManager.heartRate > 0
                            ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true)
                            : .default,
                        value: pulse
                    )

                Text(workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "--")
                    .font(.system(size: workoutManager.heartRate > 0 ? 44 : 24, weight: .bold, design: .rounded))

                Text("BPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Start a stress measurement on your iPhone")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Stress measurement (iPhone-driven — loader only on Watch)

struct WatchStressMeasurementView: View {
    @State private var spin = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(
                        AngularGradient(
                            colors: [.orange, .red, .orange.opacity(0.2)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(
                        .linear(duration: 1.1).repeatForever(autoreverses: false),
                        value: spin
                    )
            }

            Text("Measuring stress")
                .font(.caption.weight(.semibold))

            Text("Keep the app open")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .onAppear { spin = true }
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
