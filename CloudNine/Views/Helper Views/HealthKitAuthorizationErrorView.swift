import Foundation
import SwiftUI

struct AuthorizationErrorView: View {
    let description: String
//    let onRetryAuthorization: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)

            Text("HealthKit Access Required")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
//            Button("Retry Authorization") {
//                onRetryAuthorization()
//            }
//            .buttonStyle(.bordered)
//            .padding(.top, 5)
        }
        .padding()
    }
}
