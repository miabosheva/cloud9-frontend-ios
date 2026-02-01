import Foundation
import HealthKit
import CoreML
import WatchConnectivity
import SwiftUI

@MainActor
class StressDataCollector: ObservableObject {
    private let healthStore = HKHealthStore()
    private let watchConnector: WatchConnectivityManager
    private var heartRateBuffer: [(value: Double, timestamp: Date)] = []
    private let windowDuration: TimeInterval = 25.0 // seconds
    private var predictionTimer: Timer?
    private var heartRateSamplingTimer: Timer?
    private var heartRateObserver: NSObjectProtocol?
    private var lastKnownHeartRate: Double = 0.0
    private var collectionStartTime: Date?
    
    @Published var isCollecting = false
    @Published var currentPrediction: StressPrediction?
    @Published var countdown: Int = 25
    @Published var errorMessage: String?
    
    private var model: StressPredictor?
    
    init(watchConnector: WatchConnectivityManager) {
        self.watchConnector = watchConnector
        loadModel()
        setupHeartRateObserver()
    }
    
    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU
            self.model = try StressPredictor(configuration: config)
        } catch {
            print("❌ Error loading StressPredictor model: \(error)")
            errorMessage = "Failed to load stress prediction model"
        }
    }
    
    // MARK: - Heart Rate Observer
    
    private func setupHeartRateObserver() {
        // Observe heart rate updates from watch (used to update lastKnownHeartRate)
        heartRateObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HeartRateUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let heartRate = notification.userInfo?["heartRate"] as? Double else {
                return
            }
            
            // Update last known heart rate for use in sampling
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
    
    // MARK: - Start Collection
    
    func startCollection() {
        guard model != nil else {
            errorMessage = "Model not loaded"
            return
        }
        
        // Check if watch is reachable
        guard WCSession.default.isReachable else {
            errorMessage = "Apple Watch not reachable. Please ensure your watch is nearby and the app is open."
            return
        }
        
        isCollecting = true
        countdown = 25
        heartRateBuffer.removeAll()
        errorMessage = nil
        currentPrediction = nil
        lastKnownHeartRate = 0.0
        collectionStartTime = Date()
        
        // Start workout session on watch
        watchConnector.startWorkout()
        
        // Wait a moment for workout to start, then begin sampling and countdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.startHeartRateSampling()
            self.startCountdown()
        }
    }
    
    // MARK: - Heart Rate Sampling
    
    private func startHeartRateSampling() {
        // Sample heart rate every second
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
        
        // Get the most recent heart rate sample
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-5) // Look back 5 seconds
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] query, samples, error in
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
                        // Use last known value if no new sample
                        heartRate = self.lastKnownHeartRate
                    } else {
                        // Try to get from watch connector as fallback
                        heartRate = self.watchConnector.currentHeartRate
                        if heartRate > 0 {
                            self.lastKnownHeartRate = heartRate
                        }
                    }
                    
                    // Store the value for this second
                    if heartRate > 0 {
                        self.heartRateBuffer.append((value: heartRate, timestamp: currentTime))
                        print("📊 Sampled heart rate: \(heartRate) BPM at \(currentTime), Total samples: \(self.heartRateBuffer.count)")
                        
                        // Keep only last 30 seconds of data
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
        // Start countdown timer
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
        countdown = 25
        lastKnownHeartRate = 0.0
        collectionStartTime = nil
    }
    
    // MARK: - Feature Extraction
    
    private func extractFeatures() -> (hrMean: Double, hrStd: Double, hrvSDNN: Double, lfHfRatio: Double)? {
        // Get samples from last 25 seconds
        let now = Date()
        let cutoffTime = now.addingTimeInterval(-windowDuration)
        let recentSamples = heartRateBuffer.filter { $0.timestamp >= cutoffTime }
        
        guard recentSamples.count >= 10 else {
            errorMessage = "Not enough heart rate data (need at least 10 samples, got \(recentSamples.count))"
            return nil
        }
        
        let hrValues = recentSamples.map { $0.value }
        
        // Calculate HR mean
        let hrMean = hrValues.reduce(0, +) / Double(hrValues.count)
        
        // Calculate HR standard deviation
        let hrStd = calculateStandardDeviation(hrValues)
        
        // Get HRV SDNN (we'll fetch this separately)
        // Estimate LF/HF ratio (will be updated with actual HRV)
        let lfHfRatio = estimateLFHFRatio(hrMean: hrMean, hrStd: hrStd, hrvSDNN: 0)
        
        return (hrMean, hrStd, 0, lfHfRatio) // HRV will be fetched separately
    }
    
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count - 1) // Sample SD
        
        return sqrt(variance)
    }
    
    private func estimateLFHFRatio(hrMean: Double, hrStd: Double, hrvSDNN: Double) -> Double {
        // Simplified heuristic based on the guide
        if hrvSDNN < 20 {
            return 3.0 + (hrStd / 10.0)
        } else if hrvSDNN < 50 {
            return 2.0 + (hrStd / 15.0)
        } else {
            return 1.0 + (hrStd / 20.0)
        }
    }
    
    // MARK: - HRV Fetching
    
    private func getLatestHRV() async -> Double? {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { query, samples, error in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let hrvValue = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                continuation.resume(returning: hrvValue)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Prediction
    
    private func performPrediction() async {
        // Stop workout
        watchConnector.stopWorkout()
        
        // Get HRV
        let hrvSDNN = await getLatestHRV() ?? 0.0
        
        // Extract features
        guard var features = extractFeatures() else {
            stopCollection()
            return
        }
        
        // Update HRV and recalculate LF/HF ratio18
        let lfHfRatio = estimateLFHFRatio(hrMean: features.hrMean, hrStd: features.hrStd, hrvSDNN: hrvSDNN)
        
        // Create model input
        guard let model = model else {
            errorMessage = "Model not available"
            stopCollection()
            return
        }
        
        do {
            let input = StressPredictorInput(
                hr_mean: features.hrMean,
                hr_std: features.hrStd,
                hrv_sdnn: hrvSDNN,
                lf_hf_ratio: lfHfRatio
            )
            
            let output = try await model.prediction(input: input)
            
            // Convert output to stress prediction
            let stressLevel = convertToStressLevel(
                label: output.stress_label,
                probability: output.classProbability
            )
            
            currentPrediction = StressPrediction(
                stressLevel: stressLevel,
                probability: output.classProbability,
                timestamp: Date(),
                features: (hrMean: features.hrMean, hrStd: features.hrStd, hrvSDNN: hrvSDNN, lfHfRatio: lfHfRatio)
            )
            
            isCollecting = false
            
        } catch {
            errorMessage = "Prediction failed: \(error.localizedDescription)"
            print("❌ Prediction error: \(error)")
            stopCollection()
        }
    }
    
    private func convertToStressLevel(label: Int64, probability: [Int64: Double]) -> Int {
        // Simply use the probability of the predicted class and convert to 0-10 scale
        let prob = probability[label] ?? 0.5
        let level = Int(round(prob * 10))
        return min(max(level, 0), 10)
    }
}

// MARK: - Data Models

struct StressPrediction {
    let stressLevel: Int // 0-10
    let probability: [Int64: Double] // Class probabilities
    let timestamp: Date
    let features: (hrMean: Double, hrStd: Double, hrvSDNN: Double, lfHfRatio: Double)
    
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
}
