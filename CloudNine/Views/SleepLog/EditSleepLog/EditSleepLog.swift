import SwiftUI

struct EditSleepLogView: View {
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    @Environment(\.dismiss) var dismiss
    
    @State var viewModel: SleepLogViewModel
    @State var logId: String
    @State var isInsightsPresented = false
    @State var insight = ""
    @State private var formView: SleepLogFormView?
    
    init(logId: String, healthManager: HealthManager) {
        self.logId = logId
        _viewModel = State(initialValue: SleepLogViewModel(healthManager: healthManager))
    }
    
    private var isFormValid: Bool {
        formView?.isFormValid ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SleepLogFormView(
                viewModel: $viewModel,
                showAIAnalysis: true,
                onGenerateInsight: generateInsight
            )
            .background(
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        formView = SleepLogFormView(viewModel: $viewModel, showAIAnalysis: true)
                    }
                }
            )
            
            // Save Button (Fixed at bottom)
            VStack(spacing: 12) {
                if !isFormValid {
                    Text("Please complete all required fields")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button {
                    saveSleepLog()
                } label: {
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
            insight = try await viewModel.generateInsight()
            isInsightsPresented.toggle()
        } catch {
            errorManager.handle(error: error)
        }
    }
    
    private func saveSleepLog() {
        Task {
            do {
                try await healthManager.updateSleepLog(
                    sleepDataId: logId,
                    bedtime: viewModel.combinedBedtime,
                    wakeTime: viewModel.combinedWakeTime,
                    sleepQuality: viewModel.sleepQuality,
                    description: viewModel.description,
                    tags: []
                )
                dismiss()
            } catch {
                errorManager.handle(error: error)
            }
        }
    }
}
