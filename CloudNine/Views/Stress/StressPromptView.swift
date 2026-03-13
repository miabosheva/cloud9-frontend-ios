import SwiftUI

struct StressPromptView: View {
    let onSubmit: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedValue: Double = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("How stressed do you feel right now?")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                Text("Please rate your current stress level from 1 (very low) to 10 (very high).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Text("\(Int(selectedValue))")
                        .font(.system(size: 48, weight: .bold))

                    Slider(value: $selectedValue, in: 1...10, step: 1)

                    HStack {
                        Text("1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("10")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    let value = Int(selectedValue)
                    onSubmit(value)
                    dismiss()
                } label: {
                    Text("Submit")
                }
                .buttonStyle(PrimaryButtonStyle26Adaptive())
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    StressPromptView { _ in }
}

