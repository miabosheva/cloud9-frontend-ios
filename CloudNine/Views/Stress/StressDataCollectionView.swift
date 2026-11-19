import SwiftUI

struct StressDataCollectionView: View {
    @ObservedObject var collector: StressDataCollector
    let isTest: Bool
    let onCompleted: (StressPrediction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ringPulse = false

    private var phase: ViewPhase {
        if let prediction = collector.currentPrediction, !collector.isCollecting {
            return .result(prediction)
        }
        switch collector.collectionPhase {
        case .connecting, .waitingForHeartRate:
            return .starting(collector.collectionPhase)
        case .measuring:
            return .measuring
        case .failed:
            return .failed
        case .idle:
            return .prepare
        }
    }

    private var watchAppIsOpen: Bool {
        collector.watchConnector.readiness == .interactive
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
                case .starting(let subphase):
                    startingContent(subphase)
                case .measuring:
                    measuringContent
                case .result(let prediction):
                    resultContent(prediction)
                case .failed:
                    failedContent
                }

                Spacer(minLength: 24)

                bottomAction
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: collector.collectionPhase)
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: collector.currentPrediction?.stressLevel)
        }
        .onAppear {
            collector.prepareForNewSession()
            collector.watchConnector.refreshReadiness()
        }
    }

    private enum ViewPhase {
        case prepare
        case starting(StressCollectionPhase)
        case measuring
        case result(StressPrediction)
        case failed
    }

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

            watchReadinessCard

            VStack(alignment: .leading, spacing: 14) {
                instructionRow(
                    icon: "applewatch",
                    text: "Open the CloudNine app on your Apple Watch before you start."
                )
                instructionRow(icon: "hand.raised.fill", text: "Keep this screen open for the full 25 seconds.")
                instructionRow(icon: "heart.fill", text: "Stay relaxed and breathe normally.")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    private var watchReadinessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            readinessRow(
                label: "Watch paired",
                isOK: collector.watchConnector.isPaired
            )
            readinessRow(
                label: "CloudNine installed on Watch",
                isOK: collector.watchConnector.isWatchAppInstalled
            )
            readinessRow(
                label: "CloudNine open on Watch",
                isOK: watchAppIsOpen
            )

            Text(collector.watchConnector.readiness.statusLabel)
                .font(.caption)
                .foregroundStyle(watchAppIsOpen ? Color.secondary : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func startingContent(_ subphase: StressCollectionPhase) -> some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.4)

            Text(subphase == .connecting ? "Connecting to Apple Watch…" : "Waiting for heart rate…")
                .font(.title3.weight(.semibold))

            Text(subphase == .connecting
                 ? "Make sure CloudNine is open on your Watch. We're starting a brief workout for accurate readings."
                 : "Once we detect heart rate, the 25-second timer will begin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if collector.isDegradedMode {
                Text("Using recent heart rate data — wear Watch on wrist for best results.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var measuringContent: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.orange.opacity(ringPulse ? 0.18 : 0.10),
                                Color.orange.opacity(0.04),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 70,
                            endRadius: 118
                        )
                    )
                    .frame(width: 236, height: 236)
                    .scaleEffect(ringPulse ? 1.03 : 0.97)
                    .animation(
                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: ringPulse
                    )

                Circle()
                    .stroke(Color.orange.opacity(0.14), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: collector.progressFraction)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: collector.elapsedSeconds)

                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 196, height: 196)

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

                    Text("/ \(StressDataCollector.totalSeconds)")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)
            .onAppear { ringPulse = true }
            .onDisappear { ringPulse = false }

            VStack(spacing: 8) {
                Text("Measuring…")
                    .font(.title3.weight(.semibold))

                Text("Collecting heart rate from your Apple Watch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if collector.isDegradedMode {
                    Text("Using recent heart rate data — wear Watch on wrist for best results.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func resultContent(_ prediction: StressPrediction) -> some View {
        VStack(spacing: 28) {
            stressIcon(large: false)

            VStack(spacing: 12) {
                Text("Measurement Complete")
                    .font(.title3.weight(.semibold))

                Text("We collected \(prediction.hrSampleCount) heart rate samples. Next, rate how stressed you feel.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var failedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Measurement Failed")
                .font(.title3.weight(.semibold))

            if let error = collector.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

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
            .disabled(!collector.watchConnector.readiness.canStartMeasurement)

        case .starting:
            EmptyView()

        case .measuring:
            EmptyView()

        case .result:
            Button {
                if let prediction = collector.currentPrediction {
                    onCompleted(prediction)
                    dismiss()
                }
            } label: {
                Text("Continue")
            }
            .buttonStyle(PrimaryButtonStyle26Adaptive())

        case .failed:
            VStack(spacing: 12) {
                if collector.canRetry {
                    Button {
                        collector.watchConnector.refreshReadiness()
                        collector.retryCollection()
                    } label: {
                        Text("Retry")
                    }
                    .buttonStyle(PrimaryButtonStyle26Adaptive())
                }

                Button("Cancel") {
                    collector.cancelCollection()
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
    }

    private func readinessRow(label: String, isOK: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isOK ? .green : .orange)
            Text(label)
                .font(.subheadline)
        }
    }

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
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Prepare") {
    StressDataCollectionView(
        collector: StressDataCollector(watchConnector: WatchConnectivityManager()),
        isTest: false
    ) { _ in }
}
