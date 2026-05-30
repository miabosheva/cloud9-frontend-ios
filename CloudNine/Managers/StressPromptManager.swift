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
    @Published private(set) var completedTodayCount: Int
    let dailyTarget = StressPromptDailyTracker.dailyTarget

    private let watchConnector: WatchConnectivityManager
    private let repository = StressMeasurementRepository()
    private var collector: StressDataCollector?

    private var promptShownAt: Date?

    init(watchConnector: WatchConnectivityManager) {
        self.watchConnector = watchConnector
        self.completedTodayCount = StressPromptDailyTracker.shared.completedTodayCount
    }

    /// Syncs the local daily counter with Firestore and reconciles notifications.
    func refreshDailyStateAndReconcile() async {
        let dayChanged = StressPromptDailyTracker.shared.ensureCurrentDay()
        var count = StressPromptDailyTracker.shared.completedTodayCount

        if let remoteCount = try? await repository.countNonTestSamples(on: Date()), remoteCount > count {
            StressPromptDailyTracker.shared.setCompletedCount(remoteCount)
            count = remoteCount
        }

        completedTodayCount = count
        await StressNotificationScheduler.shared.reconcile(completedCount: count)

        if dayChanged {
            print("📅 New day — reset stress prompt counter and rescheduled notifications")
        }
    }

    func beginMeasurement(isTest: Bool) {
        isTestFlow = isTest
        currentPrediction = nil

        if collector == nil {
            collector = StressDataCollector(watchConnector: watchConnector)
        } else {
            collector?.prepareForNewSession()
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

        let latency = Int(Date().timeIntervalSince(promptShownAt))
        saveSample(
            prediction: prediction,
            userPrediction: value,
            userRatingStatus: .submitted,
            responseLatencySeconds: latency
        )

        isShowingPrompt = false
    }

    /// User dismissed the rating sheet — still persist model features/outputs for analysis.
    func handleUserSkippedRating() {
        guard let prediction = currentPrediction else {
            isShowingPrompt = false
            return
        }

        saveSample(
            prediction: prediction,
            userPrediction: nil,
            userRatingStatus: .skipped,
            responseLatencySeconds: nil
        )

        isShowingPrompt = false
    }

    private func saveSample(
        prediction: StressPrediction,
        userPrediction: Int?,
        userRatingStatus: UserRatingStatus,
        responseLatencySeconds: Int?
    ) {
        let sample = StressMeasurementSample(
            timestamp: prediction.timestamp,
            measurementStartedAt: prediction.measurementStartedAt,
            hrValues: prediction.hrValues,
            features: prediction.features,
            hrSampleCount: prediction.hrSampleCount,
            stepsInWindow: prediction.stepsInWindow,
            activeEnergyKcal: prediction.activeEnergyKcal,
            modelPrediction: prediction.stressLevel,
            ensembleRaw: prediction.ensembleRaw,
            xgbProbability: prediction.xgbProbability,
            annNormalized: prediction.annNormalized,
            confidenceScore: prediction.confidenceScore,
            userPrediction: userPrediction,
            userRatingStatus: userRatingStatus,
            responseLatencySeconds: responseLatencySeconds,
            activityType: prediction.activityType,
            isTest: isTestFlow,
            watchWorkoutStarted: prediction.watchWorkoutStarted
        )

        if !isTestFlow {
            StressPromptDailyTracker.shared.recordCompletion()
            completedTodayCount = StressPromptDailyTracker.shared.completedTodayCount
        }

        Task {
            do {
                try await repository.save(sample)
                lastSaveSucceeded = true
                lastSaveError = nil
                let label = userPrediction.map(String.init) ?? "none"
                print("✅ Saved stress sample (\(userRatingStatus.rawValue)), rating=\(label)")
                if !isTestFlow {
                    await StressNotificationScheduler.shared.reconcile(completedCount: completedTodayCount)
                }
            } catch {
                lastSaveSucceeded = false
                lastSaveError = error.localizedDescription
                print("❌ Failed to save stress measurement sample: \(error)")
            }
        }
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
