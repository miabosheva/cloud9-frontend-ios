import SwiftUI

struct EditSleepLogView: View {
    @Environment(HealthManager.self) var healthManager
    @Environment(\.dismiss) var dismiss
    
    @State var viewModel = SleepLogViewModel()
    @State var logId: String
    
    @State private var includeSleepTime = true
    @State private var includeOutOfBedTime = true
    
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 4) {
                Text("Edit Sleep Log")
                    .font(.title)
                Text(viewModel.formattedSleepDate)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical)
            
            Section(header: Text("Sleep Timeline")) {
                DatePicker("Bedtime", selection: $viewModel.bedtime, displayedComponents: .hourAndMinute)
                
                DatePicker("Wake Time", selection: $viewModel.wakeTime, displayedComponents: .hourAndMinute)
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadSleepLog(by: logId, sleepData: healthManager.sleepData)
        }
    }
    
    private func saveSleepLog() {
        Task {
            await healthManager.updateSleepLog(
                sleepDataId: logId,
                bedtime: viewModel.combinedBedtime,
                wakeTime: viewModel.combinedWakeTime, 
                sleepQuality: viewModel.sleepQuality,
                description: viewModel.description,
                tags: []
            )
            dismiss()
        }
    }
}
