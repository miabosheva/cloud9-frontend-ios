import SwiftUI

struct AlertErrorView: View {
    
    @Environment(ErrorManager.self) var errorManager
    
    var body: some View {
        
        @Bindable var errorManager = errorManager
        
        Color.clear
            .alert(
                errorManager.errorTitle,
                isPresented: $errorManager.isPresented,
                presenting: errorManager.error
            ) { error in
                if errorManager.canRetry {
                    Button("Retry") {
                        Task {
                            await errorManager.retry()
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        errorManager.dismiss()
                    }
                } else {
                    Button("OK") {
                        errorManager.dismiss()
                    }
                }
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}
