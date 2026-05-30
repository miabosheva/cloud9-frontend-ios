import SwiftUI

struct StressDataCollectionView: View {
    @ObservedObject var collector: StressDataCollector
    let isTest: Bool
    let onCompleted: (StressPrediction) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Collecting data from your Apple Watch…")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 32)

            Text("Please open the CloudNine Apple Watch companion app to start measuring.")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Keep your watch on and stay still if possible. This usually takes around 25 seconds.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ProgressView(value: progress, total: 25)
                .tint(.blue)
                .padding(.horizontal)

            if collector.isCollecting {
                Text("\(collector.countdown)s remaining")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(role: .cancel) {
                collector.stopCollection()
                dismiss()
            } label: {
                Text("Cancel")
            }
            .buttonStyle(SecondaryButtonStyle26Adaptive())
            .padding(.bottom, 24)
        }
        .onAppear {
            // Start a new measurement when the view appears.
            collector.startCollection()
        }
        .onChange(of: collector.countdown) { _, newValue in
            // Update progress as countdown decreases.
            progress = Double(25 - newValue)
        }
        .onChange(of: collector.currentPrediction) { _, prediction in
            guard let prediction else { return }

            let features = prediction.features
            print("📦 Collected stress prediction from watch:")
            print("   HR samples: \(prediction.hrSampleCount)")
            print("   hrrange: \(features.hrrange), hrvar: \(features.hrvar), hrstd: \(features.hrstd)")
            print("   hrmin: \(features.hrmin), hrmax: \(features.hrmax), hrkurt: \(features.hrkurt)")
            print("   XGB: \(prediction.xgbProbability), ANN norm: \(prediction.annNormalized)")
            print("   Ensemble: \(prediction.ensembleRaw) → stress level: \(prediction.stressLevel)")

            onCompleted(prediction)
            dismiss()
        }
    }
}

#Preview {
    StressDataCollectionView(
        collector: StressDataCollector(watchConnector: WatchConnectivityManager()),
        isTest: false
    ) { _ in }
}

