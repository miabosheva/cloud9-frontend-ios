import SwiftUI

struct SleepLogView: View {
    
    @Environment(HealthManager.self) var healthManager
    @State private var showingAddSleep = false
    
    var body: some View {
        NavigationStack {
            // Sleep Data Display
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Sleep Logs (Last 14 Days)")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button("Refresh") {
                        Task {
                            await healthManager.loadSleepData()
                        }
                    }
                    .font(.caption)
                    .padding(6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
                }
                
                if healthManager.sleepData.isEmpty {
                    Text("No sleep data available")
                        .foregroundColor(.gray)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(healthManager.sleepData, id: \.sessionId) { sleep in
                                SleepLogRowView(
                                    sleepData: sleep,
                                    onDelete: {
                                        Task {
                                            await healthManager.deleteSleepSession(sleep)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding()
            .cornerRadius(10)
            .onAppear {
                Task {
                    await healthManager.loadSleepData()
                }
            }
            .sheet(isPresented: $showingAddSleep) {
                AddSleepLogView()
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showingAddSleep.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Sleep Log")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
            }
        }
    }
}

#Preview {
    SleepLogView()
        .environment(HealthManager())
}
