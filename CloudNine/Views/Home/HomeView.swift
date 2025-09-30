import SwiftUI
import Charts

// MARK: - Home View
struct HomeView: View {
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    @State var navigationManager = NavigationManager()
    @State var viewModel = HomeViewModel()
    @Bindable var watchConnector: WatchConnector
    
    @State private var showingAddSleep = false
    @State private var heartRateFilter: HeartFilter = .today
    @State private var sleepFilter: SleepFilter = .thisWeek
    @State private var showingSleepDebtDetails = false
    @State private var userInfo = UserInfo()
    @State var showingInfoAlert: Bool = false
    
    private var userManager = UserManager()
    
    init(watchConnector: WatchConnector) {
        self.watchConnector = watchConnector
    }
    
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            ScrollView {
                VStack(spacing: 24) {
                    HeaderSection(
                        userInfo: userInfo,
                        onProfileTap: { navigationManager.navigate(to: .profile) }
                    )
                    
                    HealthMetricsGrid(
                        healthManager: healthManager,
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
    
    // MARK: - Data Loading
    private func loadData() async {
        do {
            try await healthManager.requestPermissions()
            try await healthManager.loadInitialData()
            userInfo = try await userManager.fetchUserInfo()
            healthManager.calculateSleepDept(user: userInfo)
        } catch {
            errorManager.handle(error: error)
        }
    }
}

#Preview {
    HomeView(watchConnector: WatchConnector())
        .environment(HealthManager())
        .environment(ErrorManager())
}
