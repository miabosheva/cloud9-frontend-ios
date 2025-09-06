import SwiftUI

struct SleepLogView: View {
    
    @Environment(HealthManager.self) var healthManager
    
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
                                            await healthManager.deleteSleepSession(sleep)
                                        }
                                    },
                                    onSave: {
                                        Task {
                                            await healthManager.addSleepLog(bedtime: sleep.bedtime, wakeTime: sleep.wakeTime)
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
            .onAppear {
                Task {
                    await healthManager.loadSleepData()
                }
            }
            .sheet(isPresented: $showingAddSleep) {
                AddSleepLogView()
            }
            .refreshable {
                Task {
                    await healthManager.loadSleepData()
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
