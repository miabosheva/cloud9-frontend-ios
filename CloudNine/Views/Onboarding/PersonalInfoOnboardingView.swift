import SwiftUI

// MARK: - Personal Info Onboarding View
struct PersonalInfoOnboardingView: View {
    let onNext: () -> Void
    var authManager = AuthManager()
    var userManager = UserManager()
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var bedtime = Date()
    @State private var wakeTime = Date()
    @State private var selectedConditions: Set<SleepConditions> = []
    @State private var height = ""
    @State private var weight = ""
    @State private var autoGenerateLogs: Bool = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Personal Information")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Tell us about yourself to personalize your experience")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Form
                VStack(spacing: 20) {
                    // Name Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            TextField("First Name", text: $firstName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            
                            TextField("Last Name", text: $lastName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }
                    }
                    
                    // Sleep Schedule Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sleep Schedule")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Bedtime:")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                DatePicker("", selection: $bedtime, displayedComponents: .hourAndMinute)
                            }
                            .padding(.horizontal)
                            
                            HStack {
                                Text("Wake Time:")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Sleep Conditions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sleep Conditions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
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
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Auto Generate Section
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Auto-generate sleep logs based on sleep schedule", isOn: $autoGenerateLogs)
                            .padding(.horizontal)
                    }
                    
                    // Body Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Body Information")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            TextField("Height (cm)", text: $height)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            
                            TextField("Weight (kg)", text: $weight)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
                
                // Next Button
                Button(action: saveAndContinue) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading || !isFormValid)
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty
    }
    
    private func saveAndContinue() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let userInfo = UserInfo(
                    firstName: firstName,
                    lastName: lastName,
                    bedtime: bedtime,
                    wakeTime: wakeTime,
                    sleepConditions: Array(selectedConditions),
                    height: Int(height) ?? 0,
                    weight: Int(weight) ?? 0,
                    autoGenerateSleepLogs: autoGenerateLogs
                )
                
                // Save user info to Firestore
                try await userManager.saveUserInfo(userInfo)
                
                await MainActor.run {
                    onNext()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save information. Please try again."
                    isLoading = false
                }
            }
        }
    }
}
