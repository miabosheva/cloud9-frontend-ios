import Foundation

/// Phase of the thesis stress experiment.
enum StressPhase: String, Codable, CaseIterable {
    case baseline = "Baseline"
    case adaptA = "Adapt_A"
    case adaptB = "Adapt_B"
}

/// Global config for the current experiment phase.
struct StressPhaseConfig {
    /// Manually set this when you switch models/phases.
    static var currentPhase: StressPhase = .baseline
}

/// Single stress measurement sample stored in Firestore.
struct StressMeasurementSample: Codable, Identifiable {
    var id: String
    var timestamp: Date

    // Sensor features (from watch / HRV window)
    var hrMean: Double
    var hrStd: Double
    var hrvSDNN: Double
    var lfHfRatio: Double

    // Model outputs
    /// 0–10 stress level predicted by the model.
    var modelPrediction: Int
    /// Model confidence score in range [0, 1].
    var confidenceScore: Double

    // User subjective label
    /// User-perceived stress level (1–10).
    var userPrediction: Int

    // Context
    var phase: String
    var responseLatencySeconds: Int
    var activityType: String
    var isTest: Bool

    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        hrMean: Double,
        hrStd: Double,
        hrvSDNN: Double,
        lfHfRatio: Double,
        modelPrediction: Int,
        confidenceScore: Double,
        userPrediction: Int,
        phase: StressPhase,
        responseLatencySeconds: Int,
        activityType: String,
        isTest: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.hrMean = hrMean
        self.hrStd = hrStd
        self.hrvSDNN = hrvSDNN
        self.lfHfRatio = lfHfRatio
        self.modelPrediction = modelPrediction
        self.confidenceScore = confidenceScore
        self.userPrediction = userPrediction
        self.phase = phase.rawValue
        self.responseLatencySeconds = responseLatencySeconds
        self.activityType = activityType
        self.isTest = isTest
    }
}

