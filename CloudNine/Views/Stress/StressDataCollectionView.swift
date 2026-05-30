import SwiftUI

struct StressDataCollectionView: View {
    @ObservedObject var collector: StressDataCollector
    let isTest: Bool
    let onCompleted: (StressPrediction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ringPulse = false

    private var phase: Phase {
        if let prediction = collector.currentPrediction, !collector.isCollecting {
            return .result(prediction)
        }
        if collector.isCollecting {
            return .measuring
        }
        return .prepare
    }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 24)

                switch phase {
                case .prepare:
                    prepareContent
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                case .measuring:
                    measuringContent
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .result(let prediction):
                    resultContent(prediction)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                Spacer(minLength: 24)

                bottomAction
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: collector.isCollecting)
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: collector.currentPrediction?.stressLevel)
        }
        .onAppear {
            collector.prepareForNewSession()
        }
        .alert("Measurement Error", isPresented: errorAlertBinding) {
            Button("OK") {
                collector.errorMessage = nil
            }
        } message: {
            if let error = collector.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Phase

    private enum Phase {
        case prepare
        case measuring
        case result(StressPrediction)
    }

    // MARK: - Layout

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.systemGray6)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button {
                if case .result = phase {
                    dismiss()
                } else {
                    collector.cancelCollection()
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(.systemGray5).opacity(0.6)))
            }
            .accessibilityLabel("Cancel measurement")

            Spacer()

            if isTest {
                Text("Test")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.12)))
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Prepare

    private var prepareContent: some View {
        VStack(spacing: 28) {
            stressIcon(large: true)

            VStack(spacing: 12) {
                Text("Stress Measurement")
                    .font(.title2.weight(.bold))

                Text("We'll collect heart rate from your Apple Watch for 25 seconds to estimate your stress level.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                instructionRow(icon: "applewatch", text: "Open the CloudNine app on your Apple Watch before you start.")
                instructionRow(icon: "hand.raised.fill", text: "Keep this screen open for the full 25 seconds.")
                instructionRow(icon: "heart.fill", text: "Stay relaxed and breathe normally unless you're testing activity.")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - Measuring

    private var measuringContent: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.12), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: collector.progressFraction)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: collector.elapsedSeconds)

                VStack(spacing: 6) {
                    Text("\(collector.elapsedSeconds)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .contentTransition(.numericText())
                        .animation(.snappy, value: collector.elapsedSeconds)

                    Text("/ \(StressDataCollector.totalSeconds)")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Circle()
                    .stroke(Color.orange.opacity(ringPulse ? 0.25 : 0.05), lineWidth: 2)
                    .scaleEffect(ringPulse ? 1.08 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: ringPulse
                    )
            }
            .frame(width: 220, height: 220)
            .onAppear { ringPulse = true }

            VStack(spacing: 8) {
                Text("Measuring…")
                    .font(.title3.weight(.semibold))

                Text("Collecting heart rate from your Apple Watch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Result

    private func resultContent(_ prediction: StressPrediction) -> some View {
        VStack(spacing: 28) {
            stressIcon(large: false)

            VStack(spacing: 8) {
                Text("Your Stress Level")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(prediction.stressLevel)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(prediction.color)

                Text(prediction.stressCategory)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(prediction.color.opacity(0.15))
                    )
            }

            VStack(spacing: 4) {
                Text("Population model estimate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Based on \(prediction.hrSampleCount) heart rate samples")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: - Bottom Action

    @ViewBuilder
    private var bottomAction: some View {
        switch phase {
        case .prepare:
            Button {
                collector.startCollection()
            } label: {
                Text("Start Measuring")
            }
            .buttonStyle(PrimaryButtonStyle26Adaptive())

        case .measuring:
            EmptyView()

        case .result(let prediction):
            Button {
                onCompleted(prediction)
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(PrimaryButtonStyle26Adaptive())
        }
    }

    // MARK: - Helpers

    private func stressIcon(large: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.15), Color.red.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: large ? 88 : 64, height: large ? 88 : 64)

            Image(systemName: "brain.head.profile")
                .font(.system(size: large ? 36 : 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.orange)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { collector.errorMessage != nil && !collector.isCollecting && collector.currentPrediction == nil },
            set: { if !$0 { collector.errorMessage = nil } }
        )
    }
}

#Preview("Prepare") {
    StressDataCollectionView(
        collector: StressDataCollector(watchConnector: WatchConnectivityManager()),
        isTest: false
    ) { _ in }
}
