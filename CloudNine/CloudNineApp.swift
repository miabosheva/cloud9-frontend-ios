import SwiftUI
import FirebaseCore
import UserNotifications

@main
struct CloudNineApp: App {
    init() {
        guard let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: filePath) else {
            fatalError("Failed to setup firebase: GoogleService-Info.plist not found or invalid")
        }

        FirebaseApp.configure(options: options)

        // Register notification delegate early (before MainTabView loads).
        _ = NotificationHandler.shared

        StressNotificationScheduler.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
