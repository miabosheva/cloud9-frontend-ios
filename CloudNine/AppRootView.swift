import SwiftUI

struct AppRootView: View {
    @StateObject private var authManager = AuthManager()
    @State private var errorManager = ErrorManager()
    @StateObject private var notificationHandler = NotificationHandler.shared
    
    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if !authManager.isAuthenticated {
                AuthenticationView()
            } else if !authManager.hasCompletedOnboarding {
                OnboardingView()
            } else if authManager.isAuthenticated && authManager.hasCompletedOnboarding {
                // Only show main app if user is authenticated AND has completed onboarding
                MainTabView()
                    .environmentObject(authManager)
            } else {
                // Fallback: if somehow we're in an invalid state, show authentication
                AuthenticationView()
            }
        }
        .environmentObject(authManager)
        .environment(errorManager)
        .onChange(of: notificationHandler.didTapStressPrompt) { _, newValue in
            // When a stress notification is tapped, MainTabView / HomeView
            // will read this via environment and start the measurement flow.
            if newValue {
                // Reset is handled in HomeView once the prompt starts.
            }
        }
    }
}

#Preview {
    AppRootView()
}
