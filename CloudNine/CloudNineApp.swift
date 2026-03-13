import SwiftUI
import FirebaseCore
import UserNotifications

@main
struct CloudNineApp: App {
    init() {
        guard let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: filePath) else {
            // In production, consider logging this error and showing a user-friendly message
            // For now, fatalError is appropriate as Firebase is required for the app to function
            fatalError("Failed to setup firebase: GoogleService-Info.plist not found or invalid")
        }
        
        FirebaseApp.configure(options: options)

        // Request notification permissions for stress prompts.
        StressNotificationScheduler.shared.requestAuthorization()
        // Schedule today's random prompts.
        StressNotificationScheduler.shared.scheduleDailyPrompts()
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
