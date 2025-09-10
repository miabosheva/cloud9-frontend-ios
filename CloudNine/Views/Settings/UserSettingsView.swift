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
    
    @State private var userInfo: UserInfo?
    
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
            
            Section(header: Text("Body Info")) {
                TextField("Height (cm)", text: $height)
                    .keyboardType(.numberPad)
                TextField("Weight (kg)", text: $weight)
                    .keyboardType(.numberPad)
            }
            
            Section {
                Button("Save") {
                    let info = UserInfo(
                        bedtime: bedtime,
                        wakeTime: wakeTime,
                        sleepConditions: Array(selectedConditions),
                        height: Int(height) ?? 0,
                        weight: Int(weight) ?? 0
                    )
                    healthManager.userInfo = info
                    errorManager.handle(error: nil, errorTitle: "User Information Saved.", alertType: .toast)
                }
            }
        }
        .task {
            bedtime = healthManager.userInfo.bedtime
            wakeTime = healthManager.userInfo.wakeTime
            selectedConditions = Set(healthManager.userInfo.sleepConditions)
            height = String(healthManager.userInfo.height)
            weight = String(healthManager.userInfo.weight)
        }
        .navigationTitle("Settings")
    }
}
