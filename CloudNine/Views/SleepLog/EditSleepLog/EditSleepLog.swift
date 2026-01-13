import SwiftUI
import SwiftUI

struct EditSleepLogView: View {
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    @Environment(\.dismiss) var dismiss
    
    @State var viewModel: SleepLogViewModel
    @State var logId: String
    @State private var isInsightsPresented = false
    @State private var insight = ""
    
    init(logId: String, healthManager: HealthManager) {
        self.logId = logId
        _viewModel = State(initialValue: SleepLogViewModel(healthManager: healthManager))
    }
    
    private var isFormValid: Bool {
        viewModel.sleepDate <= Date() && viewModel.isTimeConfigurationValid
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    DatePicker("Date", selection: $viewModel.sleepDate, in: ...Date(), displayedComponents: .date)
                    if viewModel.sleepDate > Date() {
                        ValidationWarning(message: "Sleep date cannot be in the future")
                    }
                } header: {
                    Label("Sleep Entry Date", systemImage: "calendar")
                }
                
                Section {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.indigo)
                                .frame(width: 24)
                            DatePicker("Bedtime", selection: $viewModel.bedtime, displayedComponents: .hourAndMinute)
                        }
                        HStack {
                            Image(systemName: "sunrise.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            DatePicker("Wake Time", selection: $viewModel.wakeTime, displayedComponents: .hourAndMinute)
                        }
                        Toggle(isOn: $viewModel.isNextDay) {
                            Label("Wake time is next day", systemImage: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    if !viewModel.isTimeConfigurationValid {
                        ValidationWarning(message: "Time configuration may not be logical")
                    }
                } header: {
                    Label("Sleep Timeline", systemImage: "clock.fill")
                } footer: {
                    Text("💡 Most normal sleep spans midnight. Toggle 'next day' if you wake up the day after you went to bed.")
                        .font(.caption)
                }
                
                // Summary Section
                Section {
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundColor(.purple)
                        Text("Duration:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.formatSleepDuration())
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bed.double.fill")
                                .foregroundColor(.indigo)
                                .frame(width: 20)
                            Text("Bedtime:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(viewModel.formattedDateTime(viewModel.combinedBedtime))
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Image(systemName: "alarm.fill")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            Text("Wake Time:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(viewModel.formattedDateTime(viewModel.combinedWakeTime))
                                .font(.subheadline)
                        }
                    }
                    
                    HStack {
                        if viewModel.isNextDay {
                            Image(systemName: "moon.stars.fill")
                                .foregroundColor(.blue)
                            Text("You'll sleep through midnight")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.orange)
                            Text("Same-day sleep (nap or unusual schedule)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Label("Summary", systemImage: "chart.bar.fill")
                }
                
                Section {
                    Picker("Sleep Quality", selection: $viewModel.sleepQuality) {
                        Text("Select Quality").tag(nil as SleepQuality?)
                        ForEach(SleepQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality as SleepQuality?)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $viewModel.description)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        if viewModel.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Describe your sleep experience, dreams, or how you felt...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Quality and Description", systemImage: "star.fill")
                }
                
                Section {
                    Button {
                        Task {
                            await generateInsight()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            if viewModel.isLoading { ProgressView().padding(.leading, 8) }
                            Text("Generate AI Sleep Analysis")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(isFormValid ? .blue : .gray)
                    .disabled(!isFormValid)
                } header: {
                    Label("AI Insights", systemImage: "brain.head.profile")
                }
            }
            
            VStack(spacing: 12) {
                if !isFormValid {
                    Text("Please complete all required fields")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button(action: saveSleepLog) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save Changes")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isFormValid)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $isInsightsPresented) {
            InsightsView(insightText: insight)
        }
        .navigationTitle("Sleep Log Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            do {
                try viewModel.loadSleepLog(by: logId, sleepData: healthManager.sleepData)
            } catch {
                errorManager.handle(error: error)
            }
        }
    }
    
    private func generateInsight() async {
        do {
            let sleepLog = try await healthManager.updateSleepLog(
                sleepDataId: logId,
                bedtime: viewModel.combinedBedtime,
                wakeTime: viewModel.combinedWakeTime,
                sleepQuality: viewModel.sleepQuality,
                description: viewModel.description,
                tags: []
            )
            // TODO: - Fix
            guard var sleepLog = viewModel.sleepLog else {
                throw HealthError.invalidSampleType
            }
            sleepLog.bedtime = viewModel.combinedBedtime.toLocalTime()
            sleepLog.wakeTime = viewModel.combinedWakeTime.toLocalTime()
            insight = try await viewModel.generateInsight(sleepData: sleepLog)
            isInsightsPresented.toggle()
        } catch {
            errorManager.handle(error: error)
        }
    }
    
    private func saveSleepLog() {
        Task {
            do {
                let sleepLog = try await healthManager.updateSleepLog(
                    sleepDataId: logId,
                    bedtime: viewModel.combinedBedtime,
                    wakeTime: viewModel.combinedWakeTime,
                    sleepQuality: viewModel.sleepQuality,
                    description: viewModel.description,
                    tags: []
                )
                viewModel.sleepLog = sleepLog
                dismiss()
            } catch {
                errorManager.handle(error: error)
            }
        }
    }
}
