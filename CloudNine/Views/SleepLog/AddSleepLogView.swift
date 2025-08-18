import SwiftUI

struct AddSleepLogView: View {
    @Bindable var healthManager: HealthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var sleepDate = Date()
    @State private var bedtime = Date()
    @State private var wakeTime = Date()
    
    @State private var includeSleepTime = true
    @State private var includeOutOfBedTime = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sleep Entry Date")) {
                    DatePicker("Date", selection: $sleepDate, displayedComponents: .date)
                        .onChange(of: sleepDate) { oldValue, newValue in
                            updateTimesWithNewDate()
                        }
                }
                
                Section(header: Text("Sleep Timeline")) {
                    DatePicker("Bedtime", selection: $bedtime, displayedComponents: .hourAndMinute)
                    
                    DatePicker("Wake Time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                }
                
                Section(header: Text("Sleep Quality")) {
                    Text("Duration: \(formatSleepDuration())")
                        .foregroundColor(.secondary)
                    
                    Text("Bedtime: \(formattedDateTime(combinedBedtime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Wake Time: \(formattedDateTime(combinedWakeTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button("Save Sleep Log") {
                        saveSleepLog()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Add Sleep Log")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveSleepLog()
                }
            )
        }
        .onAppear {
            setupDefaultTimes()
        }
    }
    
    // MARK: - Computed Properties for Combined Dates
    
    private var combinedBedtime: Date {
        combineDateAndTime(date: sleepDate, time: bedtime)
    }
    
    private var combinedWakeTime: Date {
        let baseDate = shouldUseNextDay(for: wakeTime) ? nextDay(from: sleepDate) : sleepDate
        return combineDateAndTime(date: baseDate, time: wakeTime)
    }
    
    // MARK: - Helper Methods
    
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = 0
        
        return calendar.date(from: combined) ?? date
    }
    
    private func shouldUseNextDay(for time: Date) -> Bool {
        let calendar = Calendar.current
        let timeHour = calendar.component(.hour, from: time)
        let bedtimeHour = calendar.component(.hour, from: bedtime)
        
        // If wake time is earlier in the day than bedtime, it's probably next day
        return timeHour < bedtimeHour || timeHour < 12 // Assuming wake times before noon are next day
    }
    
    private func nextDay(from date: Date) -> Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
    }
    
    private func updateTimesWithNewDate() {
        // When sleep date changes, update the time pickers to maintain the same time
        // but with the new date
        bedtime = combineDateAndTime(date: sleepDate, time: bedtime)
        
        // For wake times, determine if they should be next day
        let nextDayDate = nextDay(from: sleepDate)
        wakeTime = combineDateAndTime(date: shouldUseNextDay(for: wakeTime) ? nextDayDate : sleepDate, time: wakeTime)
    }
    
    private func setupDefaultTimes() {
        let calendar = Calendar.current
        let now = Date()
        
        // Default to last night
        sleepDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        
        // Set default times - these will be combined with sleepDate later
        let defaultBedtimeComponents = DateComponents(hour: 22, minute: 30)
        let defaultWakeTimeComponents = DateComponents(hour: 7, minute: 0)
        
        bedtime = calendar.date(from: defaultBedtimeComponents) ?? now
        wakeTime = calendar.date(from: defaultWakeTimeComponents) ?? now
        
        // Now update with the correct dates
        updateTimesWithNewDate()
    }
    
    private func formatSleepDuration() -> String {
        let duration = combinedWakeTime.timeIntervalSince(combinedBedtime)
        
        let hours = Int(abs(duration)) / 3600
        let minutes = Int(abs(duration)) % 3600 / 60
        
        return "\(hours)h \(minutes)m"
    }
    
    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveSleepLog() {
        Task {
            await healthManager.addSleepLog(
                bedtime: combinedBedtime,
                sleepTime: nil,
                wakeTime: combinedWakeTime,
                outOfBedTime: nil
            )
            dismiss()
            await healthManager.loadSleepChartData(for: .thisMonth)
        }
    }
}
