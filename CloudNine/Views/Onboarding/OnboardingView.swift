import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Onboarding Flow
struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var currentStep: OnboardingStep = .personalInfo
    
    enum OnboardingStep {
        case personalInfo
        case welcome
    }
    
    var body: some View {
        NavigationView {
            Group {
                switch currentStep {
                case .personalInfo:
                    PersonalInfoOnboardingView(onNext: {
                        currentStep = .welcome
                    })
                case .welcome:
                    WelcomeOnboardingView()
                }
            }
            .navigationBarHidden(true)
        }
    }
}
