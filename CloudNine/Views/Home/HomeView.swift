import SwiftUI
import Charts
import HealthKit
import WatchConnectivity
import FirebaseAuth

struct HomeView: View {
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    @State var navigationManager = NavigationManager()
    @State var viewModel = HomeViewModel()
    @Bindable var watchConnector = WatchConnector()
    
    @State private var showingAddSleep = false
    
    @State private var heartRateFilter: HeartFilter = .today
    @State private var sleepFilter: SleepFilter = .thisWeek
    @State var showingInfoAlert: Bool = false
    @State private var animate = false
    @State private var userInfo = UserInfo()
    
    private var userManager = UserManager()
    
    init(watchConnector: WatchConnector) {
        self.watchConnector = watchConnector
    }
    
    var body: some View {
        
        NavigationStack(path: $navigationManager.path) {
            ScrollView {
                VStack(spacing: 20) {
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Welcome")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("\(userInfo.firstName) \(userInfo.lastName)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            navigationManager.navigate(to: .profile)
                        }) {
                            Image(systemName: "person.circle")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top)
                    .padding(.horizontal)
                    
                    healthMetricsView
                    
                    heartRateSection
                        .padding(.horizontal)
                    
                    sleepLogsSection
                        .padding(.horizontal)
                }
            }
            .alert("Apple Watch Required", isPresented: $showingInfoAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("To begin a measurement, please open the app on your Apple Watch.")
            }
            .task {
                do {
                    try await setupView()
                } catch {
                    errorManager.handle(error: error)
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGray6))
            .customNavigation()
        }
    }
    
    private func setupView() async throws {
        try await healthManager.requestPermissions()
        watchConnector.activate()
        try await healthManager.loadInitialData()
        userInfo = try await userManager.fetchUserInfo()
    }
    
    private var healthMetricsView: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 15) {
                
                heartRateMeasureView
                
                // Temperature Card
                MetricCard(
                    title: "Temperature",
                    value: "TODO",
                    unit: "F",
                    icon: "thermometer",
                    iconColor: .green
                )
                
                // Sleep Card
                MetricCard(
                    title: "Sleep",
                    value: "TODO",
                    unit: "",
                    icon: "moon.fill",
                    iconColor: .blue
                )
            }
        }
    }
    
    private var heartRateMeasureView: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                
                VStack(alignment: .center, spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.title)
                        .foregroundColor(.red)
                        .scaleEffect(animate ? 1.2 : 1.0)
                        .animation(
                            watchConnector.isWorkoutActive ?
                            Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                            value: animate
                        )
                        .onAppear {
                            if watchConnector.isWorkoutActive {
                                animate = true
                            }
                        }
                        .onChange(of: watchConnector.isWorkoutActive) { _, newValue in
                            if newValue {
                                animate = true
                            } else {
                                animate = false
                            }
                        }
                    
                    VStack(spacing: 2) {
                        Text("\(Int(watchConnector.currentHeartRate))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Real-time Heart Rate")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button(action: {
                            watchConnector.startWorkout()
                        }) {
                            Image(systemName: "play")
                                .foregroundColor(.white)
                                .padding()
                                .background(watchConnector.isWorkoutActive ? Color.gray : Color.green)
                                .cornerRadius(8)
                        }
                        .disabled(watchConnector.isWorkoutActive || !watchConnector.isWatchConnected)
                        
                        Button(action: {
                            watchConnector.stopWorkout()
                        }) {
                            Image(systemName: "pause")
                                .foregroundColor(.white)
                                .padding()
                                .background(watchConnector.isWorkoutActive ? Color.red : Color.gray)
                                .cornerRadius(8)
                        }
                        .disabled(!watchConnector.isWorkoutActive)
                    }
                }
                
                Button {
                    showingInfoAlert.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .padding(.leading, 16)
    }
    
    private var sleepLogsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Section Header
            HStack {
                Text("Sleep Logs")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Filter Buttons
            SleepFilterButtonsView(
                selectedFilter: $sleepFilter,
                onFilterChange: { filter in
                    healthManager.loadSleepSamplesForChart(filter: sleepFilter)
                }
            )
            
            // Today's Sleep Display
            HStack {
                Text("8h")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            // Sleep Chart
            if #available(iOS 16.0, *) {
                Chart(healthManager.sleepChartData) { data in
                    BarMark(
                        x: .value("Date", data.timestamp),
                        y: .value("Hours", data.duration)
                    )
                    .foregroundStyle(data.quality == "Good" ? Color.blue : data.quality == "Fair" ? Color.orange : Color.red)
                    
                    // TODO: - Change with optimal value
                    RuleMark(y: .value("Target", 8))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(Color.gray)
                        .annotation(position: .top, alignment: .leading) {
                            Text("8 Hours")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                }
                .frame(height: 150)
                .chartYScale(domain: 0...15)
            } else {
                // Fallback chart
                SimpleBarChartView(data: healthManager.sleepData.map { $0.duration })
                    .frame(height: 150)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Section Header
            HStack {
                Text("Heart Rate")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Filter Buttons
            HeartFilterButtonsView(
                selectedFilter: $heartRateFilter,
                onFilterChange: { filter in
                    Task {
                        do {
                            try await healthManager.loadHeartRateData(for: filter)
                        } catch {
                            errorManager.handle(error: error)
                        }
                    }
                }
            )
            
            // Current Heart Rate Display
            HStack {
                Text("MIA")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            // Heart Rate Chart
            if #available(iOS 16.0, *) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Chart(healthManager.heartRateData) { data in
                        BarMark(
                            x: .value("Time", data.timestamp),
                            y: .value("Heart Rate", data.heartRate)
                        )
                        
                        // TODO: - Change with average value
                        RuleMark(y: .value("Average", 80))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundStyle(Color.gray)
                            .annotation(position: .top, alignment: .leading) {
                                Text("Average")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                    }
                    .frame(width: CGFloat(healthManager.heartRateData.count) * 60, height: 200)
                    .chartYScale(domain: 0...120)
                }
            } else {
                // Fallback chart for older iOS versions
                SimpleBarChartView(data: healthManager.heartRateData.map { $0.heartRate })
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

