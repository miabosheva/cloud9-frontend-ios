import SwiftUI

// MARK: - Header Section Component
struct HeaderSection: View {
    let userInfo: UserInfo
    let onProfileTap: () -> Void
    
    @State private var currentTime = Date()
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(userInfo.firstName)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: onProfileTap) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
    }
    
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }
}
