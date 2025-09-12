import SwiftUI

struct SleepLogView: View {
    
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    @Environment(NavigationManager.self) var navigationManager
    
    var body: some View {
        // Sleep Data Display
        VStack(alignment: .leading, spacing: 10) {
            if healthManager.sleepData.isEmpty {
                Text("No sleep data available")
                    .foregroundColor(.gray)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(healthManager.sleepData) { sleep in
                            SleepLogRowView(
                                sleepData: sleep,
                                onDelete: {
                                    Task {
                                        do {
                                            try await healthManager.deleteSleepSession(sleep)
                                        } catch {
                                            errorManager.handle(error: error)
                                        }
                                    }
                                },
                                onSave: {
                                    Task {
                                        do {
                                            try await healthManager.markLogAsSaved(
                                                sleepLog: sleep
                                            )
                                        } catch {
                                            errorManager.handle(error: error)
                                        }
                                    }
                                }
                            )
                            .onTapGesture {
                                navigationManager.navigate(to: .editLog(logId: sleep.id))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .cornerRadius(10)
        .refreshable {
            Task {
                do {
                    try await healthManager.loadSleepData()
                } catch {
                    errorManager.handle(error: error)
                }
            }
        }
        .navigationTitle("Sleep Logs")
        .navigationBarTitleDisplayMode(.inline)
        .padding(.top, 8)
    }
}
