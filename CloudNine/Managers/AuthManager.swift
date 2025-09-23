import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var hasCompletedOnboarding = false
    @Published var currentUser: User?
    
    private let db = Firestore.firestore()
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                
                if user != nil {
                    Task {
                        await self?.checkOnboardingStatus()
                    }
                } else {
                    self?.isLoading = false
                }
            }
        }
    }
    
    @MainActor
    private func checkOnboardingStatus() async {
        guard let userId = currentUser?.uid else {
            isLoading = false
            return
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            hasCompletedOnboarding = document.data()?["hasCompletedOnboarding"] as? Bool ?? false
        } catch {
            print("Error checking onboarding status: \(error)")
            hasCompletedOnboarding = false
        }
        
        isLoading = false
    }
    
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Create user document
        try await db.collection("users").document(result.user.uid).setData([
            "email": email,
            "createdAt": Timestamp(date: Date()),
            "hasCompletedOnboarding": false
        ])
    }
    
    func completeOnboarding() async throws {
        guard let userId = currentUser?.uid else { return }
        
        try await db.collection("users").document(userId).updateData([
            "hasCompletedOnboarding": true,
            "onboardingCompletedAt": Timestamp(date: Date())
        ])
        
        await MainActor.run {
            hasCompletedOnboarding = true
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
}
