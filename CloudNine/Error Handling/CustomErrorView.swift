import SwiftUI

struct CustomErrorView: View {
    
    @Environment(ErrorManager.self) var errorManager
    
    var body: some View {
        
        @Bindable var errorManager = errorManager
        
        switch(errorManager.alertType) {
        case .alert: AlertErrorView()
        case .toast: ToastView()
        }
    }
}
