import SwiftUI

struct SleepLogView: View {
    
    @Environment(HealthManager.self) var healthManager
    @State private var showingAddSleep = false
    
    var body: some View {
        NavigationStack {
            // Sleep Data Display
            ZStack(alignment: .bottomTrailing){
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
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                
                Button {
                    showingAddSleep.toggle()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Sleep Log")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
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
            .navigationTitle("Sleep Logs")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SleepLogView()
        .environment(HealthManager())
}
