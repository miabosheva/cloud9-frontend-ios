import SwiftUI

struct ToastView: View {
    
    @Environment(ErrorManager.self) var errorManager
    
    var body: some View {
        if errorManager.isPresented {
            VStack {
                Text(errorManager.errorTitle)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding(.bottom, 40)
            }
            .transition(.opacity)
            .task(id: errorManager.presentationID) {
                do {
                    try await Task.sleep(for: .seconds(2))
                    withAnimation(.easeInOut) {
                        errorManager.dismiss()
                    }
                } catch {
                    print("another toast showed")
                }
            }
        }
    }
}
