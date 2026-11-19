import Foundation
import UserNotifications
import SwiftUI

/// Bridges notification taps into the SwiftUI hierarchy so we can start the stress measurement flow.
final class NotificationHandler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    @Published var didTapStressPrompt: Bool = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if let type = userInfo["type"] as? String, type == "stress_prompt" {
            completionHandler([.banner, .sound])
            return
        }
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String, type == "stress_prompt" {
            DispatchQueue.main.async {
                self.didTapStressPrompt = true
            }
        }
        completionHandler()
    }
}
