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
                        if #available(iOS 26.0, *) {
                            Circle()
                                .frame(width: 44, height: 44)
                                .glassEffect()
                        } else {
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 44, height: 44)
                        }

                        Image(systemName: "person")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(.background)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(ProfileIconButtonStyle())
                .accessibilityLabel("Profile")
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

private struct ProfileIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
