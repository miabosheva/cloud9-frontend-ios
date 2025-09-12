import SwiftUI

struct UserSettingsView: View {
    
    @Environment(HealthManager.self) var healthManager
    @Environment(ErrorManager.self) var errorManager
    
    @State private var bedtime = Date()
    @State private var wakeTime = Date()
    @State private var selectedConditions: Set<SleepConditions> = []
    @State private var height = ""
    @State private var weight = ""
    @State private var showToast = false
    @State private var autoGenerateLogs: Bool = false
    @State private var userInfo: UserInfo?
    
    @State var viewModel = UserSettingsViewModel()
    
    var body: some View {
        Form {
            Section(header: Text("Sleep Schedule")) {
                DatePicker("Bedtime", selection: $bedtime, displayedComponents: .hourAndMinute)
                DatePicker("Wake Time", selection: $wakeTime, displayedComponents: .hourAndMinute)
            }
            
            Section(header: Text("Sleep Conditions")) {
                ForEach(SleepConditions.allCases, id: \.self) { condition in
                    Toggle(condition.displayName, isOn: Binding(
                        get: { selectedConditions.contains(condition) },
                        set: { isSelected in
                            if isSelected {
                                selectedConditions.insert(condition)
                            } else {
                                selectedConditions.remove(condition)
                            }
                        }
                    ))
                }
            }
            
            Section("Auto generate sleep entries") {
                Toggle("Auto-generate sleep logs based on sleep schedule", isOn: $autoGenerateLogs)
            }
            
            Section(header: Text("Body Info")) {
                TextField("Height (cm)", text: $height)
                    .keyboardType(.numberPad)
                TextField("Weight (kg)", text: $weight)
                    .keyboardType(.numberPad)
            }
            
            Section {
                Button("Save") {
                    Task {
                        let info = UserInfo(
                            bedtime: bedtime,
                            wakeTime: wakeTime,
                            sleepConditions: Array(selectedConditions),
                            height: Int(height) ?? 0,
                            weight: Int(weight) ?? 0,
                            autoGenerateSleepLogs: autoGenerateLogs
                        )
                        do {
                            try await viewModel.saveUserInfo(info)
                            errorManager.handle(error: nil, errorTitle: "User Information Saved.", alertType: .toast)
                        } catch {
                            errorManager.handle(error: error)
                        }
                    }
                }
            }
        }
        .task {
            let userInfo = try? viewModel.loadUserInfo()
            let defaultUserInfo = UserInfo()
            bedtime = userInfo?.bedtime ?? defaultUserInfo.bedtime
            wakeTime = userInfo?.wakeTime ?? defaultUserInfo.wakeTime
            selectedConditions = Set(userInfo?.sleepConditions ?? defaultUserInfo.sleepConditions)
            height = String(userInfo?.height ?? defaultUserInfo.height)
            weight = String(userInfo?.weight ?? defaultUserInfo.weight)
            autoGenerateLogs = userInfo?.autoGenerateSleepLogs ?? defaultUserInfo.autoGenerateSleepLogs
        }
        .navigationTitle("Settings")
    }
}
