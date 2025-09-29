import SwiftUI

struct AddSleepLogView: View {
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    @Environment(\.dismiss) var dismiss
    
    @State var viewModel: SleepLogViewModel
    
    @State private var includeSleepTime = true
    @State private var includeOutOfBedTime = true
    
    init(healthManager: HealthManager) {
        _viewModel = State(initialValue: SleepLogViewModel(healthManager: healthManager))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sleep Entry Date")) {
                    DatePicker("Date", selection: $viewModel.sleepDate, displayedComponents: .date)
                }
                
                Section(header: Text("Sleep Timeline")) {
                    DatePicker("Bedtime", selection: $viewModel.bedtime, displayedComponents: .hourAndMinute)
                    
                    DatePicker("Wake Time", selection: $viewModel.wakeTime, displayedComponents: .hourAndMinute)
                    
                    Toggle("Wake time is next day", isOn: $viewModel.isNextDay)
                    
                    // Validation warning
                    if !viewModel.isTimeConfigurationValid {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Time configuration may not be logical")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
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
                    
                    // Show helpful context
                    if viewModel.isNextDay {
                        Text("💤 You'll sleep through midnight")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    } else {
                        Text("☀️ Same-day sleep (nap or unusual schedule)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                Section {
                    Button("Save Sleep Log") {
                        saveSleepLog()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                    .disabled(!viewModel.isTimeConfigurationValid)
                }
                
                // Helper section
                Section(footer: Text("💡 Tip: 'Next day' means you wake up the day after you went to bed. Most normal sleep spans midnight.")) {
                    EmptyView()
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
            do {
                try viewModel.setupDefaultTimes()
            } catch {
                errorManager.handle(error: error)
            }
        }
    }
    
    private func saveSleepLog() {
        Task {
            do {
                try await healthManager.addSleepLog(
                    bedtime: viewModel.combinedBedtime,
                    wakeTime: viewModel.combinedWakeTime,
                    sleepQuality: viewModel.sleepQuality,
                    description: viewModel.description
                )
            } catch {
                errorManager.handle(error: error)
            }
            dismiss()
        }
    }
}

#Preview {
    AddSleepLogView(healthManager: HealthManager())
        .environment(HealthManager())
        .environment(ErrorManager())
}
