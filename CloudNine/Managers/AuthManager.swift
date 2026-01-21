import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var hasCompletedOnboarding = false
    @Published var currentUser: User?
    
    private let db = Firestore.firestore()
    private let defaults = UserDefaults.standard
    private let isAuthenticatedKey = "isAuthenticated"
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private let userIdKey = "userId"
    
    init() {
        // Set up auth state listener first
        checkAuthStatus()
        // Then check current auth state immediately (in case listener doesn't fire right away)
        checkCurrentAuthState()
    }
    
    private func checkCurrentAuthState() {
        // Check Firebase auth state synchronously
        if let currentUser = Auth.auth().currentUser {
            let persistedUserId = defaults.string(forKey: userIdKey)
            
            // If persisted userId matches current user, use persisted state temporarily
            if let persistedUserId = persistedUserId, currentUser.uid == persistedUserId {
                isAuthenticated = defaults.bool(forKey: isAuthenticatedKey)
                hasCompletedOnboarding = defaults.bool(forKey: hasCompletedOnboardingKey)
                self.currentUser = currentUser
            } else {
                // User exists but doesn't match persisted state, clear it
                clearPersistedState()
                isAuthenticated = true
                self.currentUser = currentUser
                // Will check onboarding status via listener
            }
            
            // Verify onboarding status from Firebase
            Task {
                await checkOnboardingStatus()
            }
        } else {
            // No current user, clear persisted state
            clearPersistedState()
            isAuthenticated = false
            hasCompletedOnboarding = false
            currentUser = nil
            isLoading = false
        }
    }
    
    private func persistState() {
        if let userId = currentUser?.uid {
            defaults.set(isAuthenticated, forKey: isAuthenticatedKey)
            defaults.set(hasCompletedOnboarding, forKey: hasCompletedOnboardingKey)
            defaults.set(userId, forKey: userIdKey)
        } else {
            clearPersistedState()
        }
    }
    
    private func clearPersistedState() {
        defaults.removeObject(forKey: isAuthenticatedKey)
        defaults.removeObject(forKey: hasCompletedOnboardingKey)
        defaults.removeObject(forKey: userIdKey)
    }
    
    func checkAuthStatus() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let previousUserId = self.currentUser?.uid
                self.currentUser = user
                let wasAuthenticated = self.isAuthenticated
                self.isAuthenticated = user != nil
                
                // If user changed or authentication state changed, update persisted state
                if wasAuthenticated != self.isAuthenticated || user?.uid != previousUserId {
                    if let user = user {
                        // User is authenticated, persist state and check onboarding
                        self.persistState()
                        Task {
                            await self.checkOnboardingStatus()
                        }
                    } else {
                        // User signed out, clear everything
                        self.clearPersistedState()
                        self.hasCompletedOnboarding = false
                        self.isLoading = false
                    }
                } else if user != nil {
                    // Same user, but make sure onboarding status is checked
                    Task {
                        await self.checkOnboardingStatus()
                    }
                } else {
                    // No user
                    self.isLoading = false
                }
            }
        }
    }
    
    @MainActor
    private func checkOnboardingStatus() async {
        guard let userId = currentUser?.uid else {
            isLoading = false
            hasCompletedOnboarding = false
            persistState()
            return
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            let onboardingStatus = document.data()?["hasCompletedOnboarding"] as? Bool ?? false
            hasCompletedOnboarding = onboardingStatus
            persistState()
        } catch {
            print("Error checking onboarding status: \(error)")
            // On error, check persisted state as fallback
            hasCompletedOnboarding = defaults.bool(forKey: hasCompletedOnboardingKey)
        }
        
        isLoading = false
    }
    
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
        // State will be updated by the auth state listener
    }
    
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Create user document
        try await db.collection("users").document(result.user.uid).setData([
            "email": email,
            "createdAt": Timestamp(date: Date()),
            "hasCompletedOnboarding": false
        ])
        
        // State will be updated by the auth state listener
    }
    
    func completeOnboarding() async throws {
        guard let userId = currentUser?.uid else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await db.collection("users").document(userId).updateData([
            "hasCompletedOnboarding": true
        ])
        
        await MainActor.run {
            hasCompletedOnboarding = true
            persistState()
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        // State will be cleared by the auth state listener
    }
    
    /// Resets onboarding status when user info is not found
    /// This should be called when the app detects that user info doesn't exist
    func resetOnboardingStatus() {
        // Update state immediately on main thread so view updates right away
        // This will trigger AppRootView to show OnboardingView
        let userId = currentUser?.uid
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hasCompletedOnboarding = false
            self.persistState()
            
            // Update Firebase in the background (don't wait for it)
            if let userId = userId {
                Task {
                    do {
                        try await self.db.collection("users").document(userId).updateData([
                            "hasCompletedOnboarding": false
                        ])
                    } catch {
                        print("Error updating onboarding status in Firebase: \(error)")
                    }
                }
            }
        }
    }
}
