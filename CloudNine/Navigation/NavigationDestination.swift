import SwiftUI

struct NavigationDestination: ViewModifier {
    func body(content: Content) -> some View {
            content
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .profile:
                        UserSettings()
                    }
                }
        }
}

extension View {
    func customNavigation() -> some View {
        self.modifier(NavigationDestination())
    }
}
