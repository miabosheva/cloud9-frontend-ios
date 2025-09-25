import SwiftUI

// MARK: - Personal Info Onboarding View
struct PersonalInfoOnboardingView: View {
    let onNext: () -> Void
    var authManager = AuthManager()
    var userManager = UserManager()
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var bedtime = UserInfo.defaultBedtime()
    @State private var wakeTime = UserInfo.defaultWakeTime()
    @State private var selectedConditions: Set<SleepConditions> = []
    @State private var height = ""
    @State private var weight = ""
    @State private var autoGenerateLogs: Bool = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Form Content
                LazyVStack(spacing: 24) {
                    nameSection
                    sleepScheduleSection
                    sleepConditionsSection
                    bodyInfoSection
                    automationSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                
                // Error Message
                if !errorMessage.isEmpty {
                    errorMessageView
                }
                
                // Continue Button
                continueButton
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .hideKeyboardWhenTappedAround()
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("Personal Information")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Tell us about yourself to personalize your sleep tracking experience")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Name Section
    private var nameSection: some View {
        VStack(spacing: 16) {
            sectionHeader(title: "Your Name", icon: "person.fill", color: .blue)
            
            VStack(spacing: 12) {
                customTextField(
                    title: "First Name",
                    text: $firstName,
                    icon: "person",
                    placeholder: "Enter your first name"
                )
                
                customTextField(
                    title: "Last Name",
                    text: $lastName,
                    icon: "person.badge.plus",
                    placeholder: "Enter your last name"
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Sleep Schedule Section
    private var sleepScheduleSection: some View {
        VStack(spacing: 16) {
            sectionHeader(title: "Sleep Schedule", icon: "clock.fill", color: .purple)
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.indigo)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bedtime")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("When you usually go to sleep")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    DatePicker("", selection: $bedtime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wake Time")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("When you usually wake up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sleep Duration")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Based on your schedule")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(SleepDurationHelper.calculateSleepDuration(bedtime: bedtime, wakeTime: wakeTime))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Sleep Conditions Section
    private var sleepConditionsSection: some View {
        VStack(spacing: 16) {
            sectionHeader(title: "Sleep Conditions", icon: "heart.text.square.fill", color: .red)
            
            VStack(spacing: 0) {
                if selectedConditions.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("No conditions selected")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                
                ForEach(Array(SleepConditions.allCases.enumerated()), id: \.element) { index, condition in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(condition.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                if let description = condition.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { selectedConditions.contains(condition) },
                                set: { isSelected in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isSelected {
                                            selectedConditions.insert(condition)
                                        } else {
                                            selectedConditions.remove(condition)
                                        }
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedConditions.contains(condition) {
                                    selectedConditions.remove(condition)
                                } else {
                                    selectedConditions.insert(condition)
                                }
                            }
                        }
                        
                        if index < SleepConditions.allCases.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Body Info Section
    private var bodyInfoSection: some View {
        VStack(spacing: 16) {
            sectionHeader(title: "Body Information", icon: "figure.stand", color: .green)
            
            VStack(spacing: 12) {
                customTextField(
                    title: "Height",
                    text: $height,
                    icon: "ruler",
                    placeholder: "170",
                    keyboardType: .numberPad,
                    unit: "cm"
                )
                
                customTextField(
                    title: "Weight",
                    text: $weight,
                    icon: "scalemass",
                    placeholder: "70",
                    keyboardType: .numberPad,
                    unit: "kg"
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            
            Text("Optional: Used for more accurate health insights")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Automation Section
    private var automationSection: some View {
        VStack(spacing: 16) {
            sectionHeader(title: "Automation", icon: "gearshape.2.fill", color: .orange)
            
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.gray)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-generate Sleep Logs")
                        .font(.body)
                        .fontWeight(.medium)
                    Text("Automatically create entries based on your sleep schedule")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Toggle("", isOn: $autoGenerateLogs)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Error Message View
    private var errorMessageView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Continue Button
    private var continueButton: some View {
        Button(action: saveAndContinue) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                }
                
                Text("Continue")
                    .fontWeight(.semibold)
                    .font(.body)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFormValid ? Color.blue : Color.gray)
                    .shadow(color: isFormValid ? Color.blue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            )
            .foregroundColor(.white)
            .scaleEffect(isLoading ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isLoading)
        }
        .disabled(isLoading || !isFormValid)
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Views
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
    
    private func customTextField(
        title: String,
        text: Binding<String>,
        icon: String,
        placeholder: String,
        keyboardType: UIKeyboardType = .default,
        unit: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .padding(.trailing, 8)
            
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.leading)
            
            if let unit = unit {
                Text(unit)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
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
