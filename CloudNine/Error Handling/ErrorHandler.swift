import SwiftUI

struct ErrorHandler: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay {
            CustomErrorView()
        }
    }
}

extension View {
    func handleGlobalErrors() -> some View {
        self.modifier(ErrorHandler())
    }
}
