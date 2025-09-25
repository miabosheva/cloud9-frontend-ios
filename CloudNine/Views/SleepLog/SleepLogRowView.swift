import SwiftUI

struct SleepLogRowView: View {
    let sleepData: SleepData
    
    @Environment(NavigationManager.self) var navigationManager
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    @State var showDeleteAlert: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Leading status indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(sleepData.savedFlag ? .green : .blue)
                .frame(width: 4, height: 60)
            
            VStack(alignment: .leading, spacing: 10) {
                // Header row with date and duration
                HStack {
                    Text(sleepData.date, style: .date)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(sleepData.formattedDuration)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Sleep times row
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.orange)
                            .font(.system(.caption, weight: .medium))
                            .frame(width: 16)
                        
                        Text(sleepData.formattedBedtime)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.yellow)
                            .font(.system(.caption, weight: .medium))
                            .frame(width: 16)
                        
                        Text(sleepData.formattedWakeTime)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let sleepQuality = sleepData.sleepQuality {
                        Text(sleepQuality.rawValue)
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(sleepData.qualityColor.opacity(0.15))
                            .foregroundColor(sleepData.qualityColor)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(sleepData.qualityColor.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
            }
            
            // Action button
            Button(action: {
                if sleepData.savedFlag {
                    showDeleteAlert = true
                } else {
                    saveData()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(sleepData.savedFlag ? .red.opacity(0.1) : .green.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Circle()
                        .stroke(sleepData.savedFlag ? .red.opacity(0.3) : .green.opacity(0.3), lineWidth: 1)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: sleepData.savedFlag ? "trash" : "checkmark")
                        .foregroundColor(sleepData.savedFlag ? .red : .green)
                        .font(.system(.caption, weight: .semibold))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(showDeleteAlert ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: showDeleteAlert)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(
                    color: .black.opacity(0.05),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 0.5)
        )
        .scaleEffect(sleepData.savedFlag ? 1.0 : 0.98)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sleepData.savedFlag)
        .alert("Delete Sleep Log", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this sleep log entry? This action cannot be undone.")
        }
        .onTapGesture {
            navigationManager.navigate(to: .editLog(logId: sleepData.id))
        }
    }
    
    func saveData() {
        Task {
            do {
                try await healthManager.markLogAsSaved(
                    sleepLog: sleepData
                )
            } catch {
                errorManager.handle(error: error)
            }
        }
    }
    
    func deleteData() {
        Task {
            do {
                try await healthManager.deleteSleepSession(sleepData)
            } catch {
                errorManager.handle(error: error)
            }
        }
    }
}

// MARK: - Preview Helper
#if DEBUG
struct SleepLogRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            // Saved entry preview
            SleepLogRowView(
                sleepData: SampleSleepData.saved
            )
            
            // Unsaved entry preview
            SleepLogRowView(
                sleepData: SampleSleepData.unsaved
            )
            
            // Entry with metadata
            SleepLogRowView(
                sleepData: SampleSleepData.withMetadata
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.light)
        
        VStack(spacing: 12) {
            SleepLogRowView(
                sleepData: SampleSleepData.saved
            )
            
            SleepLogRowView(
                sleepData: SampleSleepData.unsaved
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}

// Sample data for previews using actual SleepData structure
struct SampleSleepData {
    static let saved: SleepData = {
        let bedtime = Date().addingTimeInterval(-10 * 3600) // 10 hours ago
        let wakeTime = Date().addingTimeInterval(-2 * 3600) // 2 hours ago
        let duration = wakeTime.timeIntervalSince(bedtime)
        
        return SleepData(
            date: Date(),
            bedtime: bedtime,
            wakeTime: wakeTime,
            duration: duration,
            savedFlag: true,
            sleepQuality: .good,
            description: "Great night's sleep"
        )
    }()
    
    static let unsaved: SleepData = {
        let bedtime = Date().addingTimeInterval(-86400 - 9 * 3600) // Yesterday, 9 hours ago
        let wakeTime = Date().addingTimeInterval(-86400 - 1.5 * 3600) // Yesterday, 1.5 hours ago
        let duration = wakeTime.timeIntervalSince(bedtime)
        
        return SleepData(
            date: Date().addingTimeInterval(-86400),
            bedtime: bedtime,
            wakeTime: wakeTime,
            duration: duration,
            savedFlag: false,
            sleepQuality: .excellent
        )
    }()
    
    static let withMetadata: SleepData = {
        let bedtime = Date().addingTimeInterval(-2 * 86400 - 8.5 * 3600) // 2 days ago
        let wakeTime = Date().addingTimeInterval(-2 * 86400 - 0.5 * 3600) // 2 days ago
        let duration = wakeTime.timeIntervalSince(bedtime)
        
        var sleepData = SleepData(
            date: Date().addingTimeInterval(-2 * 86400),
            bedtime: bedtime,
            wakeTime: wakeTime,
            duration: duration,
            savedFlag: true,
            sleepQuality: .fair,
            description: "Woke up a few times during the night"
        )
        sleepData.tags = ["restless", "work-stress"]
        return sleepData
    }()
}
#endif
