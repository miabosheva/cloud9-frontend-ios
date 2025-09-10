import SwiftUI

struct AddSleepLogView: View {
    @Environment(HealthManager.self) var healthManager
    @Environment(\.dismiss) var dismiss
    
    @State var viewModel = SleepLogViewModel()
    
    @State private var includeSleepTime = true
    @State private var includeOutOfBedTime = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sleep Entry Date")) {
                    DatePicker("Date", selection: $viewModel.sleepDate, displayedComponents: .date)
                        .onChange(of: viewModel.sleepDate) { oldValue, newValue in
                            viewModel.updateTimesWithNewDate()
                        }
                }
                
                Section(header: Text("Sleep Timeline")) {
                    DatePicker("Wake Time", selection: $viewModel.wakeTime, displayedComponents: .hourAndMinute)
                    
                    HStack {
                        DatePicker("Bedtime", selection: $viewModel.bedtime, displayedComponents: .hourAndMinute)
                        Toggle("is Next Day", isOn: $viewModel.isNextDay)
                    }
                }
                
                Section("Quality and Description") {
                    Picker("Sleep Quality", selection: $viewModel.sleepQuality) {
                        ForEach(SleepQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    
                    TextField("Describe your sleep...", text: $viewModel.description)
                }
                
                Section(header: Text("Summary")) {
                    Text("Duration: \(viewModel.formatSleepDuration())")
                        .foregroundColor(.secondary)
                    
                    Text("Bedtime: \(viewModel.formattedDateTime(viewModel.combinedBedtime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Wake Time: \(viewModel.formattedDateTime(viewModel.combinedWakeTime))")
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
                }
            )
        }
        .onAppear {
            viewModel.setupDefaultTimes()
        }
    }
    
    private func saveSleepLog() {
        Task {
            await healthManager.addSleepLog(
                bedtime: viewModel.combinedBedtime,
                wakeTime: viewModel.combinedWakeTime,
                sleepQuality: viewModel.sleepQuality,
                description: viewModel.description
            )
            dismiss()
        }
    }
}

#Preview {
    AddSleepLogView()
        .environment(HealthManager())
}
