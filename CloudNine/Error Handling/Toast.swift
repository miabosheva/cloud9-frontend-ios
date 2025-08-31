import SwiftUI

struct Toast<Presenting>: View where Presenting: View {
    @Binding var isShowing: Bool
    let message: String
    let presenting: () -> Presenting

    var body: some View {
        ZStack(alignment: .bottom) {
            presenting()
            
            if isShowing {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: isShowing)
                    .padding(.bottom, 40)
            }
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String) -> some View {
        Toast(isShowing: isShowing, message: message) {
            self
        }
    }
}
