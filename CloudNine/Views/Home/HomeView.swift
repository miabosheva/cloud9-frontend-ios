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
    @State var isLoading = true
    
    private var userManager = UserManager()
    
    init(watchConnector: WatchConnectivityManager) {
        self.watchConnector = watchConnector
    }
    
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            ZStack {
                if isLoading {
                    LoadingView()
                } else {
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
                    .refreshable {
                        Task {
                            await fetchData()
                        }
                    }
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
                await loadData()
            }
            .navigationBarHidden(true)
            .customNavigation()
        }
    }
    
    // MARK: - Initial Data Loading
    private func loadData() async {
        do {
            await fetchData()
            try await healthManager.requestPermissions()
        } catch {
            errorManager.handle(error: error)
        }
    }
    
    // MARK: - Data Loading
    private func fetchData() async {
        do {
            isLoading = true
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date.now)
            
            // Get today's sleep (the sleep you woke up from this morning)
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
            
            isLoading = false
        } catch {
            isLoading = false
            errorManager.handle(error: error)
        }
    }
}

#Preview {
    HomeView(watchConnector: WatchConnectivityManager())
        .environment(HealthManager())
        .environment(ErrorManager())
}
