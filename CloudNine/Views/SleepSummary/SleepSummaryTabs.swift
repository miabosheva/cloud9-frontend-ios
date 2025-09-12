import SwiftUI

struct SleepSummaryTabs: View {
    
    @Environment(HealthManager.self) var healthManager
    
    @State private var selectedTab = 0
    @State var navigationManager = NavigationManager()
    @State var showingAddSleep: Bool = false
    
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { selectedTab = 0 }) {
                        Text("Calendar")
                            .foregroundColor(selectedTab == 0 ? .blue : .gray)
                            .fontWeight(selectedTab == 0 ? .bold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button(action: { selectedTab = 1 }) {
                        Text("Logs")
                            .foregroundColor(selectedTab == 1 ? .blue : .gray)
                            .fontWeight(selectedTab == 1 ? .bold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Swipeable pages
                TabView(selection: $selectedTab) {
                    SleepCalendarView()
                        .tag(0)
                    
                    SleepLogView()
                        .environment(navigationManager)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .customNavigation()
            }
            .sheet(isPresented: $showingAddSleep) {
                AddSleepLogView(healthManager: healthManager)
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
        }
    }
}

