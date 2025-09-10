import Foundation

@MainActor
@Observable
class ErrorManager {
    
    var error: Error?
    var errorTitle: String = "Error"
    var alertType: ErrorPresentationType = .alert
    var retryAction: () async -> Void = {}
    var canRetry: Bool = false
    var isPresented: Bool = false
    var presentationID: UUID = UUID()
    
    func handle(error: Error?,
                errorTitle: String = "Error",
                alertType: ErrorPresentationType = .alert,
                canRetry: Bool = false,
                retryAction: @escaping () async -> Void = {}) {
        self.error = error
        self.errorTitle = errorTitle
        self.canRetry = canRetry
        self.retryAction = retryAction
        self.alertType = alertType
        presentationID = UUID()
        isPresented = true
    }
    
    func dismiss() {
        error = nil
        errorTitle = ""
        isPresented = false
        canRetry = false
        retryAction = {}
    }
    
    func retry() async {
        await retryAction()
        dismiss()
    }
}
