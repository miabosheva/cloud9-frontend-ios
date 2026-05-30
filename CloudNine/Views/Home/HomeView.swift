import SwiftUI
import Charts

// MARK: - Home View
struct HomeView: View {
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var stressPromptManager: StressPromptManager
    @State var navigationManager = NavigationManager()
    @State var viewModel = HomeViewModel()
    @Bindable var watchConnector: WatchConnectivityManager
    
    @State private var showingAddSleep = false
    @State private var heartRateFilter: HeartFilter = .today
    @State private var sleepFilter: SleepFilter = .thisWeek
    @State private var stepsFilter: StepsFilter = .today
    @State private var showingSleepDebtDetails = false
    @State private var userInfo = UserInfo()
    @State var showingInfoAlert: Bool = false
    @State private var isShowingSaveResultAlert: Bool = false
    @State private var saveResultTitle: String = ""
    @State private var saveResultMessage: String = ""
    
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

                        StressPredictionCard()
                            .padding(.horizontal)
                        
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
                        
                        StepsSection(
                            healthManager: healthManager,
                            errorManager: errorManager,
                            stepsFilter: $stepsFilter
                        )
                        .padding(.horizontal)

                        // Developer / testing button to trigger stress prompt manually
                        Button {
                            stressPromptManager.beginMeasurement(isTest: true)
                        } label: {
                            Text("Trigger Stress Prompt (Test)")
                        }
                        .buttonStyle(SecondaryButtonStyle26Adaptive())
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
            .alert(saveResultTitle, isPresented: $isShowingSaveResultAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveResultMessage)
            }
            .sheet(isPresented: $showingSleepDebtDetails) {
                SleepDebtDetailView(sleepDebtResult: healthManager.sleepDebtResult)
            }
            // Full-screen stress measurement flow
            .fullScreenCover(isPresented: $stressPromptManager.isShowingDataCollection) {
                StressDataCollectionView(
                    collector: stressPromptManager.makeCollector(),
                    isTest: stressPromptManager.isTestFlow
                ) { prediction in
                    stressPromptManager.handleDataCollectionCompleted(prediction: prediction)
                }
            }
            // User 1–10 prompt sheet
            .sheet(isPresented: $stressPromptManager.isShowingPrompt) {
                StressPromptView(
                    onSubmit: { value in
                        stressPromptManager.handleUserResponse(value)
                    },
                    onSkip: {
                        stressPromptManager.handleUserSkippedRating()
                    }
                )
                .applyPromptSheetStyle()
            }
            .onChange(of: stressPromptManager.lastSaveSucceeded) { _, newValue in
                guard newValue else { return }
                saveResultTitle = "Saved"
                saveResultMessage = "Thank you! Your stress rating was saved successfully."
                isShowingSaveResultAlert = true
            }
            .onChange(of: stressPromptManager.lastSaveError) { _, errorText in
                guard let errorText, !errorText.isEmpty else { return }
                saveResultTitle = "Save Failed"
                saveResultMessage = "Your stress rating could not be saved.\n\n\(errorText)"
                isShowingSaveResultAlert = true
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
            // Ensure user is authenticated
            guard authManager.isAuthenticated, authManager.currentUser != nil else {
                // User not authenticated, AuthManager will handle redirect
                return
            }
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date.now)
            
            let todaysSleep = healthManager.sleepData.filter { data in
                calendar.isDate(data.date, inSameDayAs: today)
            }
            
            try await healthManager.loadInitialData()
            // Load steps data for the current filter
            try await healthManager.loadStepsData(for: stepsFilter)
            
            // Try to fetch user info
            do {
                userInfo = try await userManager.fetchUserInfo()
                healthManager.calculateSleepDebt(user: userInfo)
                
                if let sleepDebtResult = healthManager.sleepDebtResult {
                    watchConnector.sendAllSleepData(
                        sleepDebtResult,
                        duration: todaysSleep.totalFormattedDuration,
                        quality: todaysSleep.first?.sleepQuality?.rawValue
                    )
                }
            } catch let error as UserManagerError {
                // If user info is not found or invalid, redirect to onboarding (no error shown)
                switch error {
                case .userInfoNotFound, .invalidUserInfoData:
                    // User info not found or invalid - redirect to onboarding silently
                    authManager.resetOnboardingStatus()
                    return
                case .userNotAuthenticated:
                    // User not authenticated, AuthManager will handle redirect
                    return
                case .fetchFailed(let underlyingError):
                    // Check if it's a decoding error (corrupted userInfo) - redirect to onboarding
                    if underlyingError is DecodingError {
                        authManager.resetOnboardingStatus()
                        return
                    }
                    // Other fetch errors, show error
                    await MainActor.run {
                        errorManager.handle(error: error)
                    }
                default:
                    // Other errors, show error but don't redirect
                    await MainActor.run {
                        errorManager.handle(error: error)
                    }
                }
            } catch {
                // For any other error, show error
                await MainActor.run {
                    errorManager.handle(error: error)
                }
            }
        } catch {
            await MainActor.run {
                errorManager.handle(error: error)
            }
        }
    }
}

#Preview {
    HomeView(watchConnector: WatchConnectivityManager())
        .environment(HealthManager())
        .environment(ErrorManager())
        .environmentObject(StressPromptManager(watchConnector: WatchConnectivityManager()))
}
