import SwiftUI

struct NavigationDestination: ViewModifier {
    @Environment(HealthManager.self) var healthManager
    
    func body(content: Content) -> some View {
            content
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .profile:
                        UserSettingsView()
                    case .editLog(let logId):
                        EditSleepLogView(logId: logId, healthManager: healthManager)
                    }
                }
        }
}

extension View {
    func customNavigation() -> some View {
        self.modifier(NavigationDestination())
    }
}
