import SwiftUI

struct SleepLogView: View {
    
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    
    @State private var showingAddSleep = false
    @State var navigationManager = NavigationManager()
    
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
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
            .sheet(isPresented: $showingAddSleep) {
                AddSleepLogView(healthManager: healthManager)
            }
            .refreshable {
                Task {
                    do {
                        try await healthManager.loadSleepData()
                    } catch {
                        errorManager.handle(error: error)
                    }
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showingAddSleep.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Log")
                        }
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                }
            }
            .navigationTitle("Sleep Logs")
            .navigationBarTitleDisplayMode(.large)
            .customNavigation()
        }
    }
}

#Preview {
    SleepLogView()
        .environment(HealthManager())
}
