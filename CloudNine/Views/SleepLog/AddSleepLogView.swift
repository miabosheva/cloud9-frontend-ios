import SwiftUI

struct AddSleepLogView: View {
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    @Environment(\.dismiss) var dismiss
    
    @State var viewModel: SleepLogViewModel
    @State private var formView: SleepLogFormView?
    
    init(healthManager: HealthManager) {
        _viewModel = State(initialValue: SleepLogViewModel(healthManager: healthManager))
    }
    
    private var isFormValid: Bool {
        formView?.isFormValid ?? false
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SleepLogFormView(viewModel: $viewModel)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.onAppear {
                                formView = SleepLogFormView(viewModel: $viewModel)
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
                            Text("Save Sleep Log")
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
                dismiss()
            } catch {
                errorManager.handle(error: error)
            }
        }
    }
}

#Preview {
    AddSleepLogView(healthManager: HealthManager())
        .environment(HealthManager())
        .environment(ErrorManager())
}
