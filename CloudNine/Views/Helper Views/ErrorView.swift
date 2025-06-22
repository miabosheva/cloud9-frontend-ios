import SwiftUI

struct ErrorView: View {
    
    var description: String
    
    var body: some View {
        Text(description)
    }
}

#Preview {
    ErrorView(description: "This is an Error.")
}
