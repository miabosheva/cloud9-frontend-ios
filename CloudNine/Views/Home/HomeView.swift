import SwiftUI
import Charts

// MARK: - Home View
struct HomeView: View {
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    @State var navigationManager = NavigationManager()
    @State var viewModel = HomeViewModel()
    @Bindable var watchConnector: WatchConnectivityManager
    
    @State private var showingAddSleep = false
    @State private var heartRateFilter: HeartFilter = .today
    @State private var sleepFilter: SleepFilter = .thisWeek
    @State private var showingSleepDebtDetails = false
    @State private var userInfo = UserInfo()
    @State var showingInfoAlert: Bool = false
    
    private var userManager = UserManager()
    
    init(watchConnector: WatchConnectivityManager) {
        self.watchConnector = watchConnector
    }
    
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        HeaderSection(
                            userInfo: userInfo,
                            onProfileTap: { navigationManager.navigate(to: .profile) }
                        )
                        
                        HealthMetricsGrid(
                            watchConnector: watchConnector,
                            showingSleepDebtDetails: $showingSleepDebtDetails,
                            showingInfoAlert: $showingInfoAlert
                        )
                        
                        SleepInsightsSection(
                            healthManager: healthManager,
                            errorManager: errorManager,
                            sleepFilter: $sleepFilter
                        )
                        .padding(.horizontal)
                        
                        HeartRateSection(
                            healthManager: healthManager,
                            errorManager: errorManager,
                            watchConnector: watchConnector,
                            heartRateFilter: $heartRateFilter
                        )
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .refreshable {
                Task {
                    await fetchData()
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .alert("Apple Watch Required", isPresented: $showingInfoAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("To begin a measurement, please open the app on your Apple Watch.")
            }
            .sheet(isPresented: $showingSleepDebtDetails) {
                SleepDebtDetailView(sleepDebtResult: healthManager.sleepDeptResult)
            }
            .task {
                await fetchData()
            }
            .navigationBarHidden(true)
            .customNavigation()
        }
    }
    
    // MARK: - Data Loading
    private func fetchData() async {
        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date.now)
            
            let todaysSleep = healthManager.sleepData.filter { data in
                calendar.isDate(data.date, inSameDayAs: today)
            }
            
            try await healthManager.loadInitialData()
            userInfo = try await userManager.fetchUserInfo()
            healthManager.calculateSleepDept(user: userInfo)
            
            if let sleepDeptResult = healthManager.sleepDeptResult {
                watchConnector.sendAllSleepData(
                    sleepDeptResult,
                    duration: todaysSleep.totalFormattedDuration,
                    quality: todaysSleep.first?.sleepQuality?.rawValue
                )
            }
        } catch {
//            errorManager.handle(error: error)
        }
    }
}

#Preview {
    HomeView(watchConnector: WatchConnectivityManager())
        .environment(HealthManager())
        .environment(ErrorManager())
}
