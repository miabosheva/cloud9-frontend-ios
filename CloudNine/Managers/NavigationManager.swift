import SwiftUI

@MainActor
@Observable
class NavigationManager {
    var path = NavigationPath()
    
    func navigate(to destination: Destination) {
        path.append(destination)
    }
    
    func popToRoot() {
        path = NavigationPath()
    }
}
