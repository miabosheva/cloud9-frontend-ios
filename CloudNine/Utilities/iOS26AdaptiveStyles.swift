import SwiftUI

// MARK: - Button Styles

struct PrimaryButtonStyle26Adaptive: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            configuration.label
                .font(.headline)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .foregroundStyle(Color.white)
                .clipShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        } else {
            configuration.label
                .font(.headline)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .opacity(configuration.isPressed ? 0.85 : 1.0)
        }
    }
}

struct SecondaryButtonStyle26Adaptive: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .strokeBorder(Color.accentColor.opacity(configuration.isPressed ? 0.4 : 0.8), lineWidth: 1)
                )
                .foregroundStyle(Color.accentColor)
        } else {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.clear)
                .foregroundColor(.purple)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.6), lineWidth: 1)
                )
        }
    }
}

// MARK: - Sheet Styling Helpers

extension View {
    /// Apply modern iOS 26 sheet styling for the stress prompt while keeping older defaults on iOS 16–25.
    @ViewBuilder
    func applyPromptSheetStyle() -> some View {
        if #available(iOS 26, *) {
            self
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }

    /// Apply full-height style for the data collection sheet on iOS 26, with a simple fallback.
    @ViewBuilder
    func applyDataCollectionSheetStyle() -> some View {
        if #available(iOS 26, *) {
            self
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}

