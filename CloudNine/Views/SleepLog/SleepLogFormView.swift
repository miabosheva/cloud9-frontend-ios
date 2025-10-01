import SwiftUI

struct SleepLogFormView: View {
    @Binding var viewModel: SleepLogViewModel
    let showAIAnalysis: Bool
    let onGenerateInsight: (() async -> Void)?
    
    init(
        viewModel: Binding<SleepLogViewModel>,
        showAIAnalysis: Bool = false,
        onGenerateInsight: (() async -> Void)? = nil
    ) {
        self._viewModel = viewModel
        self.showAIAnalysis = showAIAnalysis
        self.onGenerateInsight = onGenerateInsight
    }
    
    // MARK: - Validation Properties
    
    private var isSleepDateValid: Bool {
        viewModel.sleepDate <= Date()
    }
    
    var isFormValid: Bool {
        isSleepDateValid &&
        viewModel.isTimeConfigurationValid
    }
    
    var body: some View {
        Form {
            // Sleep Entry Date Section
            Section {
                DatePicker("Date", selection: $viewModel.sleepDate, in: ...Date(), displayedComponents: .date)
                
                if !isSleepDateValid {
                    ValidationWarning(message: "Sleep date cannot be in the future")
                }
            } header: {
                Label("Sleep Entry Date", systemImage: "calendar")
            }
            
            // Sleep Timeline Section
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
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                            Text("Wake time is next day")
                        }
                    }
                }
                .padding(.vertical, 4)
                
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
            
            // Quality and Description Section
            Section {
                Picker("Sleep Quality", selection: $viewModel.sleepQuality) {
                    Text("Select Quality").tag(nil as SleepQuality?)
                    ForEach(SleepQuality.allCases, id: \.self) { quality in
                        HStack {
                            Text(quality.rawValue)
                        }
                        .tag(quality as SleepQuality?)
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
                .padding(.vertical, 4)
            } header: {
                Label("Quality and Description", systemImage: "star.fill")
            }
            
            if showAIAnalysis {
                Section {
                    Button {
                        Task {
                            await onGenerateInsight?()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding(.leading, 8)
                            }
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
        }
    }
}

// MARK: - Validation Warning Component
struct ValidationWarning: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SleepLogFormView(viewModel: .constant(SleepLogViewModel(healthManager: HealthManager())))
}
