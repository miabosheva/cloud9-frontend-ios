import Foundation
import HealthKit
import WatchConnectivity
import SwiftUI

@MainActor
class StressDataCollector: ObservableObject {
    private let healthStore = HKHealthStore()
    private let watchConnector: WatchConnectivityManager
    private var heartRateBuffer: [(value: Double, timestamp: Date)] = []
    private let windowDuration: TimeInterval = StressFeatureExtractor.windowDuration
    private var predictionTimer: Timer?
    private var heartRateSamplingTimer: Timer?
    private var heartRateObserver: NSObjectProtocol?
    private var lastKnownHeartRate: Double = 0.0
    private var collectionStartTime: Date?

    @Published var isCollecting = false
    @Published var currentPrediction: StressPrediction?
    @Published var countdown: Int = 25
    @Published var errorMessage: String?

    static let totalSeconds = Int(StressFeatureExtractor.windowDuration)

    /// Seconds elapsed during an active measurement (0…25).
    var elapsedSeconds: Int {
        guard isCollecting else { return 0 }
        return Self.totalSeconds - countdown
    }

    var progressFraction: Double {
        Double(elapsedSeconds) / Double(Self.totalSeconds)
    }

    private var predictor: StressEnsemblePredictor?

    init(watchConnector: WatchConnectivityManager) {
        self.watchConnector = watchConnector
        loadPredictor()
        setupHeartRateObserver()
    }

    private func loadPredictor() {
        do {
            predictor = try StressEnsemblePredictor()
        } catch {
            print("❌ Error loading stress ensemble: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Heart Rate Observer

    private func setupHeartRateObserver() {
        heartRateObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HeartRateUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let heartRate = notification.userInfo?["heartRate"] as? Double else {
                return
            }

            if self.isCollecting && heartRate > 0 {
                self.lastKnownHeartRate = heartRate
            }
        }
    }

    deinit {
        if let observer = heartRateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Session Lifecycle

    /// Resets UI state when opening the measurement screen (does not start workout).
    func prepareForNewSession() {
        stopCollection()
        currentPrediction = nil
        errorMessage = nil
    }

    /// Cancels workout, discards samples, clears prediction — no inference.
    func cancelCollection() {
        prepareForNewSession()
    }

    func startCollection() {
        guard predictor != nil else {
            errorMessage = "Stress prediction models not loaded"
            return
        }

        guard WCSession.default.isReachable else {
            errorMessage = "Apple Watch not reachable. Please ensure your watch is nearby and the app is open."
            return
        }

        isCollecting = true
        countdown = Self.totalSeconds
        heartRateBuffer.removeAll()
        errorMessage = nil
        currentPrediction = nil
        lastKnownHeartRate = 0.0
        collectionStartTime = Date()

        watchConnector.startWorkout()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.startHeartRateSampling()
            self.startCountdown()
        }
    }

    // MARK: - Heart Rate Sampling

    private func startHeartRateSampling() {
        heartRateSamplingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, self.isCollecting else {
                    timer.invalidate()
                    return
                }

                await self.sampleHeartRate()
            }
        }
    }

    private func sampleHeartRate() async {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-5)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, _ in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                Task { @MainActor in
                    let currentTime = Date()
                    var heartRate: Double = self.lastKnownHeartRate

                    if let sample = samples?.first as? HKQuantitySample {
                        let hrUnit = HKUnit.count().unitDivided(by: .minute())
                        heartRate = sample.quantity.doubleValue(for: hrUnit)
                        self.lastKnownHeartRate = heartRate
                    } else if self.lastKnownHeartRate > 0 {
                        heartRate = self.lastKnownHeartRate
                    } else {
                        heartRate = self.watchConnector.currentHeartRate
                        if heartRate > 0 {
                            self.lastKnownHeartRate = heartRate
                        }
                    }

                    if heartRate > 0 {
                        self.heartRateBuffer.append((value: heartRate, timestamp: currentTime))
                        print("📊 Sampled heart rate: \(heartRate) BPM, total: \(self.heartRateBuffer.count)")

                        let cutoffTime = currentTime.addingTimeInterval(-30)
                        self.heartRateBuffer = self.heartRateBuffer.filter { $0.timestamp >= cutoffTime }
                    }

                    continuation.resume()
                }
            }

            self.healthStore.execute(query)
        }
    }

    private func startCountdown() {
        predictionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                if self.countdown > 0 {
                    self.countdown -= 1
                } else {
                    timer.invalidate()
                    await self.performPrediction()
                }
            }
        }
    }

    func stopCollection() {
        isCollecting = false
        predictionTimer?.invalidate()
        predictionTimer = nil
        heartRateSamplingTimer?.invalidate()
        heartRateSamplingTimer = nil
        watchConnector.stopWorkout()
        heartRateBuffer.removeAll()
        countdown = Self.totalSeconds
        lastKnownHeartRate = 0.0
        collectionStartTime = nil
    }

    // MARK: - Prediction

    private func performPrediction() async {
        watchConnector.stopWorkout()

        let cutoffTime = Date().addingTimeInterval(-windowDuration)
        let recentSamples = heartRateBuffer.filter { $0.timestamp >= cutoffTime }
        let hrValues = recentSamples.map(\.value)

        guard hrValues.count >= StressFeatureExtractor.minimumSampleCount else {
            errorMessage = "Not enough heart rate data (need at least \(StressFeatureExtractor.minimumSampleCount) samples, got \(hrValues.count))"
            stopCollection()
            return
        }

        guard let features = StressFeatureExtractor.extract(from: hrValues) else {
            errorMessage = "Failed to extract HR features"
            stopCollection()
            return
        }

        let windowEnd = Date()
        let windowStart = collectionStartTime ?? cutoffTime
        let windowMetrics = await StressMeasurementHealthKitContext.fetchWindowMetrics(
            healthStore: healthStore,
            from: windowStart,
            to: windowEnd
        )
        let activityType = StressActivityClassifier.classify(
            features: features,
            stepsInWindow: windowMetrics.steps,
            activeEnergyKcal: windowMetrics.activeEnergyKcal
        )

        guard let predictor else {
            errorMessage = "Stress prediction models not available"
            stopCollection()
            return
        }

        do {
            let result = try await predictor.predict(features: features)

            currentPrediction = StressPrediction(
                stressLevel: result.stressLevel,
                ensembleRaw: result.ensembleRaw,
                xgbProbability: result.xgbProbability,
                annNormalized: result.annNormalized,
                timestamp: Date(),
                features: features,
                hrValues: hrValues,
                hrSampleCount: hrValues.count,
                measurementStartedAt: collectionStartTime,
                stepsInWindow: windowMetrics.steps,
                activeEnergyKcal: windowMetrics.activeEnergyKcal,
                activityType: activityType
            )

            isCollecting = false
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Prediction error: \(error)")
            stopCollection()
        }
    }
}

// MARK: - Data Models

struct StressPrediction: Equatable {
    let id: UUID = UUID()
    let stressLevel: Int
    let ensembleRaw: Double
    let xgbProbability: Double
    let annNormalized: Double
    let timestamp: Date
    let features: StressHRFeatures
    let hrValues: [Double]
    let hrSampleCount: Int
    let measurementStartedAt: Date?
    let stepsInWindow: Int
    let activeEnergyKcal: Double
    let activityType: StressActivityType

    var confidenceScore: Double {
        max(ensembleRaw, 1.0 - ensembleRaw)
    }

    var stressCategory: String {
        switch stressLevel {
        case 0...3: return "Low"
        case 4...6: return "Moderate"
        case 7...10: return "High"
        default: return "Unknown"
        }
    }

    var color: Color {
        switch stressLevel {
        case 0...3: return .green
        case 4...6: return .yellow
        case 7...10: return .red
        default: return .gray
        }
    }

    static func == (lhs: StressPrediction, rhs: StressPrediction) -> Bool {
        lhs.id == rhs.id
    }
}
