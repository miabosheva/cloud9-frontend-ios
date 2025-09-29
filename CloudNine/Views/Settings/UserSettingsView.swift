import SwiftUI

struct UserSettingsView: View {
    
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    
    private var authManager = AuthManager()
    private var userManager = UserManager()
    
    @State private var bedtime = Date()
    @State private var wakeTime = Date()
    @State private var selectedConditions: Set<SleepConditions> = []
    @State private var height = ""
    @State private var weight = ""
    @State private var showToast = false
    @State private var autoGenerateLogs: Bool = false
    @State private var userInfo: UserInfo?
    @State private var trackingGoal: TrackingGoal = .balanced
    @State private var sleepDuration: Double = 8.0
    @State private var isLoading = false
    @State private var showLogoutAlert = false
    
    var body: some View {
        Form {
            // Sleep Schedule Section
            Section {
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.indigo)
                        .frame(width: 24)
                    DatePicker("Bedtime", selection: $bedtime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }
                
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    DatePicker("Wake Time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }
                
                // Sleep duration preview
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Sleep Duration")
                    Spacer()
                    Text(SleepDurationHelper.calculateSleepDuration(bedtime: bedtime, wakeTime: wakeTime))
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            } header: {
                Label("Sleep Schedule", systemImage: "clock.circle")
            } footer: {
                Text("Set your preferred sleep and wake times for consistent scheduling.")
            }
            
            // Sleep Goal Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        Text("Tracking Goal")
                            .font(.headline)
                    }
                    
                    Picker("Tracking Goal", selection: $trackingGoal) {
                        ForEach(TrackingGoal.allCases, id: \.self) { goal in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text(goal.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .tag(goal)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                HStack {
                    Image(systemName: "bed.double.fill")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    Text("Recommended Sleep")
                    Spacer()
                    TextField("8.0", value: $sleepDuration, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("hours")
                        .foregroundColor(.secondary)
                }
            } header: {
                Label("Sleep Goals", systemImage: "target")
            } footer: {
                Text("Choose how you want to track sleep debt and set your ideal sleep duration.")
            }
            
            // Health Conditions Section
            Section {
                if selectedConditions.isEmpty {
                    HStack {
                        Image(systemName: "heart.circle")
                            .foregroundColor(.red)
                        Text("No conditions selected")
                            .foregroundColor(.secondary)
                    }
                }
                
                ForEach(SleepConditions.allCases, id: \.self) { condition in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(condition.displayName)
                                .font(.body)
                            if let description = condition.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { selectedConditions.contains(condition) },
                            set: { isSelected in
                                if isSelected {
                                    selectedConditions.insert(condition)
                                } else {
                                    selectedConditions.remove(condition)
                                }
                            }
                        ))
                        .labelsHidden()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedConditions.contains(condition) {
                            selectedConditions.remove(condition)
                        } else {
                            selectedConditions.insert(condition)
                        }
                    }
                }
            } header: {
                Label("Sleep Conditions", systemImage: "heart.text.square")
            } footer: {
                Text("Select any conditions that may affect your sleep quality.")
            }
            
            // Body Information Section
            Section {
                HStack {
                    Image(systemName: "ruler")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Height")
                    Spacer()
                    TextField("170", text: $height)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("cm")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "scalemass")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("Weight")
                    Spacer()
                    TextField("70", text: $weight)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("kg")
                        .foregroundColor(.secondary)
                }
            } header: {
                Label("Body Information", systemImage: "person.circle")
            } footer: {
                Text("Optional: Used for more accurate health insights.")
            }
            
            // Automation Section
            Section {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-generate Sleep Logs")
                            .font(.body)
                        Text("Automatically create entries based on your schedule")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $autoGenerateLogs)
                        .labelsHidden()
                }
            } header: {
                Label("Automation", systemImage: "gearshape.2")
            }
            
            // Actions Section
            Section {
                Button(action: saveUserInfo) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Save Settings")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .disabled(isLoading)
                .buttonStyle(.plain)
            }
            
            Section {
                Button(action: { showLogoutAlert = true }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("Sign Out")
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .hideKeyboardWhenTappedAround()
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .task {
            await loadUserInfo()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadUserInfo() async {
        do {
            let userInfo = try await userManager.fetchUserInfo()
            
            await MainActor.run {
                self.userInfo = userInfo
                bedtime = userInfo.bedtime
                wakeTime = userInfo.wakeTime
                selectedConditions = Set(userInfo.sleepConditions)
                height = String(userInfo.height)
                weight = String(userInfo.weight)
                autoGenerateLogs = userInfo.autoGenerateSleepLogs
                trackingGoal = userInfo.trackingGoal
                sleepDuration = userInfo.sleepDuration
            }
        } catch {
            errorManager.handle(error: error)
        }
    }
    
    private func saveUserInfo() {
        Task {
            isLoading = true
            
            do {
                guard let userInfo else {
                    throw HealthError.userInfoNotFound
                }
                
                let info = UserInfo(
                    firstName: userInfo.firstName,
                    lastName: userInfo.lastName,
                    bedtime: bedtime,
                    wakeTime: wakeTime,
                    sleepConditions: Array(selectedConditions),
                    height: Int(height) ?? 0,
                    weight: Int(weight) ?? 0,
                    autoGenerateSleepLogs: autoGenerateLogs,
                    trackingGoal: trackingGoal,
                    sleepDuration: sleepDuration
                )
                
                try await userManager.saveUserInfo(info)
                await MainActor.run {
                    isLoading = false
                    errorManager.handle(
                        error: nil,
                        errorTitle: "Settings Saved Successfully!",
                        alertType: .toast
                    )
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorManager.handle(error: error)
                }
            }
        }
    }
    
    private func signOut() {
        do {
            try authManager.signOut()
        } catch {
            errorManager.handle(error: error)
        }
    }
}
