import Foundation
import SwiftUI

@MainActor
class StressPromptManager: ObservableObject {
    @Published var isShowingDataCollection = false
    @Published var isShowingPrompt = false
    @Published var currentPrediction: StressPrediction?
    @Published var isTestFlow = false
    @Published var lastSaveError: String?
    @Published var lastSaveSucceeded: Bool = false

    private let watchConnector: WatchConnectivityManager
    private let repository = StressMeasurementRepository()
    private var collector: StressDataCollector?

    private var promptShownAt: Date?

    init(watchConnector: WatchConnectivityManager) {
        self.watchConnector = watchConnector
    }

    func beginMeasurement(isTest: Bool) {
        isTestFlow = isTest
        currentPrediction = nil

        if collector == nil {
            collector = StressDataCollector(watchConnector: watchConnector)
        }

        isShowingDataCollection = true
    }

    func handleDataCollectionCompleted(prediction: StressPrediction) {
        currentPrediction = prediction
        isShowingDataCollection = false

        promptShownAt = Date()
        isShowingPrompt = true
    }

    func handleUserResponse(_ value: Int) {
        guard let prediction = currentPrediction,
              let promptShownAt = promptShownAt else {
            isShowingPrompt = false
            return
        }

        let responseAt = Date()
        let latency = Int(responseAt.timeIntervalSince(promptShownAt))

        let sample = StressMeasurementSample(
            features: prediction.features,
            hrSampleCount: prediction.hrSampleCount,
            modelPrediction: prediction.stressLevel,
            ensembleRaw: prediction.ensembleRaw,
            xgbProbability: prediction.xgbProbability,
            annNormalized: prediction.annNormalized,
            confidenceScore: prediction.confidenceScore,
            userPrediction: value,
            responseLatencySeconds: latency,
            activityType: "unknown",
            isTest: isTestFlow
        )

        Task {
            do {
                try await repository.save(sample)
                lastSaveSucceeded = true
                lastSaveError = nil
                print("✅ Successfully saved stress measurement sample with rating \(value)")
            } catch {
                lastSaveSucceeded = false
                lastSaveError = error.localizedDescription
                print("❌ Failed to save stress measurement sample: \(error)")
            }
        }

        isShowingPrompt = false
    }

    func makeCollector() -> StressDataCollector {
        if let collector {
            return collector
        }
        let newCollector = StressDataCollector(watchConnector: watchConnector)
        collector = newCollector
        return newCollector
    }
}
