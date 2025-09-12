import SwiftUI

@MainActor
@Observable
class NavigationManager {
    var path = NavigationPath()
    
    func navigate(to destination: Destination) {
        path.append(destination)
        print("navigated to \(destination)")
    }
    
    func popToRoot() {
        path = NavigationPath()
    }
}
