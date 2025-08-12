import SwiftUI

struct AddSleepLogView: View {
    @Bindable var healthManager: HealthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var sleepDate = Date()
    @State private var bedtime = Date()
    @State private var sleepTime = Date()
    @State private var wakeTime = Date()
    @State private var outOfBedTime = Date()
    
    @State private var includeSleepTime = true
    @State private var includeOutOfBedTime = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sleep Date")) {
                    DatePicker("Date", selection: $sleepDate, displayedComponents: .date)
                }
                
                Section(header: Text("Sleep Timeline")) {
                    DatePicker("Bedtime", selection: $bedtime, displayedComponents: .hourAndMinute)
                    
                    Toggle("Track Sleep Start Time", isOn: $includeSleepTime)
                    if includeSleepTime {
                        DatePicker("Fell Asleep", selection: $sleepTime, displayedComponents: .hourAndMinute)
                    }
                    
                    DatePicker("Wake Time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    
                    Toggle("Track Out of Bed Time", isOn: $includeOutOfBedTime)
                    if includeOutOfBedTime {
                        DatePicker("Out of Bed", selection: $outOfBedTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section(header: Text("Sleep Quality")) {
                    // You could add sleep quality, notes, etc. here
                    Text("Duration: \(formatSleepDuration())")
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
    
    private func setupDefaultTimes() {
        let calendar = Calendar.current
        let now = Date()
        
        // Default to last night
        sleepDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        
        // Default bedtime: 10:30 PM yesterday
        bedtime = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: sleepDate) ?? sleepDate
        
        // Default sleep time: 11:00 PM yesterday  
        sleepTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: sleepDate) ?? sleepDate
        
        // Default wake time: 7:00 AM today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: sleepDate) ?? sleepDate
        wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        
        // Default out of bed: 7:15 AM today
        outOfBedTime = calendar.date(bySettingHour: 7, minute: 15, second: 0, of: tomorrow) ?? tomorrow
    }
    
    private func formatSleepDuration() -> String {
        let startTime = includeSleepTime ? sleepTime : bedtime
        let duration = wakeTime.timeIntervalSince(startTime)
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        return "\(hours)h \(minutes)m"
    }
    
    private func saveSleepLog() {
        healthManager.addSleepLog(
            bedtime: bedtime,
            sleepTime: includeSleepTime ? sleepTime : nil,
            wakeTime: wakeTime,
            outOfBedTime: includeOutOfBedTime ? outOfBedTime : nil
        ) { success in
            DispatchQueue.main.async {
                if success {
                    dismiss()
                    healthManager.loadSleepData()
                }
            }
        }
    }
}
