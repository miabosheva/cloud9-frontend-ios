import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Onboarding Content
            VStack(spacing: 20) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Welcome to CloudNine!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Let's get you set up for better sleep tracking")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Next Button
            VStack(spacing: 16) {
                Button(action: completeOnboarding) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        
                        Text("Get Started")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading)
                .padding(.horizontal)
                
                Text("You can always change your preferences later")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .navigationBarHidden(true)
    }
    
    private func completeOnboarding() {
        isLoading = true
        
        Task {
            do {
                try await authManager.completeOnboarding()
            } catch {
                print("Error completing onboarding: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}


#Preview {
    OnboardingView()
}
