import SwiftUI

struct AppRootView: View {
    @StateObject private var authManager = AuthManager()
    @State private var errorManager = ErrorManager()
    
    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if !authManager.isAuthenticated {
                AuthenticationView()
            } else if !authManager.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .environmentObject(authManager)
        .environment(errorManager)
    }
}

#Preview {
    AppRootView()
}
