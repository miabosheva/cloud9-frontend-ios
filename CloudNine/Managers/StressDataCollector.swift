import Foundation
import HealthKit
import WatchConnectivity
import SwiftUI

enum StressCollectionPhase: Equatable {
    case idle
    case connecting
    case waitingForHeartRate
    case measuring
    case failed
}

@MainActor
class StressDataCollector: ObservableObject {
    private let healthStore = HKHealthStore()
    let watchConnector: WatchConnectivityManager
    private var heartRateBuffer: [(value: Double, timestamp: Date)] = []
    private let windowDuration: TimeInterval = StressFeatureExtractor.windowDuration
    private var predictionTimer: Timer?
    private var heartRateSamplingTimer: Timer?
    private var heartRateObserver: NSObjectProtocol?
    private var heartRateWindowSampler: HeartRateWindowSampler?
    private var lastKnownHeartRate: Double = 0.0
    private var collectionStartTime: Date?
    private var measurementWindowStart: Date?
    private var collectionTask: Task<Void, Never>?

    @Published var collectionPhase: StressCollectionPhase = .idle
    @Published var isCollecting = false
    @Published var currentPrediction: StressPrediction?
    @Published var countdown: Int = 25
    @Published var errorMessage: String?
    @Published var canRetry = false
    @Published var isDegradedMode = false
    @Published private(set) var watchWorkoutStarted = true

    static let totalSeconds = Int(StressFeatureExtractor.windowDuration)
    private static let heartRateWaitTimeout: TimeInterval = 15

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
                self.recordHeartRate(heartRate, at: Date())
            }
        }
    }

    deinit {
        if let observer = heartRateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func prepareForNewSession() {
        stopCollection()
        currentPrediction = nil
        errorMessage = nil
        canRetry = false
        isDegradedMode = false
        collectionPhase = .idle
    }

    func cancelCollection() {
        prepareForNewSession()
    }

    func startCollection() {
        guard predictor != nil else {
            fail(with: "Stress prediction models not loaded", retry: false)
            return
        }

        watchConnector.refreshReadiness()
        guard watchConnector.readiness.canStartMeasurement else {
            fail(with: watchConnector.readiness.statusLabel, retry: false)
            return
        }

        collectionTask?.cancel()
        collectionTask = Task {
            await runCollectionFlow()
        }
    }

    func retryCollection() {
        errorMessage = nil
        canRetry = false
        startCollection()
    }

    private func runCollectionFlow() async {
        resetCollectionState()
        collectionPhase = .connecting
        isCollecting = true

        guard watchConnector.requestStressMeasurementStart() != nil else {
            fail(with: watchConnector.readiness.statusLabel, retry: false)
            return
        }

        let workoutResult = await watchConnector.waitForWorkoutStart(timeout: 10)

        if Task.isCancelled { return }

        switch workoutResult {
        case .workoutStarted:
            watchWorkoutStarted = true
            isDegradedMode = false
        case .timedOut:
            let recentRates = await HeartRateWindowSampler.fetchRecentWatchHeartRates(
                healthStore: healthStore,
                within: 90
            )
            if recentRates.count >= StressFeatureExtractor.minimumSampleCount {
                watchWorkoutStarted = false
                isDegradedMode = true
                watchConnector.stopWorkout()
            } else {
                fail(with: WatchMeasurementStartError.workoutStartTimedOut.localizedDescription, retry: true)
                return
            }
        }

        collectionPhase = .waitingForHeartRate
        startHeartRateWindowSampler()

        let gotHeartRate = await waitForFirstHeartRate(timeout: Self.heartRateWaitTimeout)
        if Task.isCancelled { return }

        if !gotHeartRate {
            fail(with: WatchMeasurementStartError.noHeartRateData.localizedDescription, retry: true)
            return
        }

        beginMeasuringCountdown()
    }

    private func resetCollectionState() {
        countdown = Self.totalSeconds
        heartRateBuffer.removeAll()
        errorMessage = nil
        currentPrediction = nil
        lastKnownHeartRate = 0.0
        collectionStartTime = Date()
        measurementWindowStart = nil
        canRetry = false
        isDegradedMode = false
        watchWorkoutStarted = true
    }

    private func waitForFirstHeartRate(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !heartRateBuffer.isEmpty || lastKnownHeartRate > 0 {
                if heartRateBuffer.isEmpty, lastKnownHeartRate > 0 {
                    recordHeartRate(lastKnownHeartRate, at: Date())
                }
                return true
            }
            if let bpm = await HeartRateWindowSampler.fetchLatestWatchHeartRate(healthStore: healthStore, within: 15) {
                recordHeartRate(bpm, at: Date())
                return true
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return !heartRateBuffer.isEmpty
    }

    private func beginMeasuringCountdown() {
        measurementWindowStart = Date()
        heartRateBuffer.removeAll()
        collectionPhase = .measuring
        startHeartRateSampling()
        startCountdown()
    }

    private func startHeartRateWindowSampler() {
        let sampler = HeartRateWindowSampler(healthStore: healthStore)
        heartRateWindowSampler = sampler
        sampler.start { [weak self] bpm, date in
            Task { @MainActor in
                self?.recordHeartRate(bpm, at: date)
            }
        }
    }

    private func recordHeartRate(_ bpm: Double, at date: Date) {
        guard bpm > 0 else { return }
        lastKnownHeartRate = bpm
        heartRateBuffer.append((value: bpm, timestamp: date))

        if let windowStart = measurementWindowStart {
            let windowEnd = windowStart.addingTimeInterval(windowDuration)
            heartRateBuffer = heartRateBuffer.filter { $0.timestamp >= windowStart && $0.timestamp <= windowEnd }
        } else {
            let cutoff = date.addingTimeInterval(-30)
            heartRateBuffer = heartRateBuffer.filter { $0.timestamp >= cutoff }
        }
    }

    /// One BPM per second slot over the 25s measurement window (latest sample wins per bucket).
    private func downsampleToOneHertz(
        _ samples: [(value: Double, timestamp: Date)],
        windowStart: Date
    ) -> [Double] {
        let bucketCount = Self.totalSeconds
        var bucketed: [Int: Double] = [:]

        for sample in samples.sorted(by: { $0.timestamp < $1.timestamp }) {
            let offset = sample.timestamp.timeIntervalSince(windowStart)
            guard offset >= 0, offset <= windowDuration else { continue }
            let bucket = min(Int(offset), bucketCount - 1)
            bucketed[bucket] = sample.value
        }

        return (0..<bucketCount).compactMap { bucketed[$0] }
    }

    private func hrValuesForFeatureWindow() -> [Double] {
        guard let windowStart = measurementWindowStart else { return [] }
        let windowEnd = windowStart.addingTimeInterval(windowDuration)
        let inWindow = heartRateBuffer.filter { $0.timestamp >= windowStart && $0.timestamp <= windowEnd }
        return downsampleToOneHertz(inWindow, windowStart: windowStart)
    }

    private func startHeartRateSampling() {
        heartRateSamplingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, self.isCollecting else {
                    timer.invalidate()
                    return
                }
                await self.pollHeartRate()
            }
        }
    }

    private func pollHeartRate() async {
        if let bpm = await HeartRateWindowSampler.fetchLatestWatchHeartRate(healthStore: healthStore, within: 10) {
            recordHeartRate(bpm, at: Date())
        } else if watchConnector.currentHeartRate > 0 {
            recordHeartRate(watchConnector.currentHeartRate, at: Date())
        } else if lastKnownHeartRate > 0 {
            recordHeartRate(lastKnownHeartRate, at: Date())
        }
    }

    private func startCountdown() {
        predictionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }
                if self.countdown > 0 {
                    self.countdown -= 1
                } else {
                    timer.invalidate()
                    await self.performPrediction()
                }
            }
        }
    }

    private func fail(with message: String, retry: Bool) {
        errorMessage = message
        canRetry = retry
        collectionPhase = .failed
        stopCollection()
    }

    func stopCollection() {
        collectionTask?.cancel()
        collectionTask = nil
        isCollecting = false
        if collectionPhase != .failed {
            collectionPhase = .idle
        }
        predictionTimer?.invalidate()
        predictionTimer = nil
        heartRateSamplingTimer?.invalidate()
        heartRateSamplingTimer = nil
        heartRateWindowSampler?.stop()
        heartRateWindowSampler = nil
        watchConnector.stopWorkout()
        countdown = Self.totalSeconds
    }

    private func performPrediction() async {
        watchConnector.stopWorkout()
        heartRateWindowSampler?.stop()
        heartRateWindowSampler = nil

        guard let windowStart = measurementWindowStart else {
            fail(with: "Measurement window not started", retry: true)
            return
        }

        let windowEnd = windowStart.addingTimeInterval(windowDuration)
        let hrValues = hrValuesForFeatureWindow()

        guard hrValues.count >= StressFeatureExtractor.minimumSampleCount else {
            fail(
                with: "Not enough heart rate data (need at least \(StressFeatureExtractor.minimumSampleCount) samples, got \(hrValues.count))",
                retry: true
            )
            return
        }

        guard let features = StressFeatureExtractor.extract(from: hrValues) else {
            fail(with: "Failed to extract HR features", retry: true)
            return
        }

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
            fail(with: "Stress prediction models not available", retry: false)
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
                measurementStartedAt: windowStart,
                stepsInWindow: windowMetrics.steps,
                activeEnergyKcal: windowMetrics.activeEnergyKcal,
                activityType: activityType,
                watchWorkoutStarted: watchWorkoutStarted
            )

            isCollecting = false
            collectionPhase = .idle
        } catch {
            fail(with: error.localizedDescription, retry: true)
        }
    }
}

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
    let watchWorkoutStarted: Bool

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
