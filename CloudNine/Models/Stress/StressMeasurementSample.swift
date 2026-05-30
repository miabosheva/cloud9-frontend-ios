import Foundation

/// Single stress measurement sample stored in Firestore.
struct StressMeasurementSample: Codable, Identifiable {
    var id: String
    var timestamp: Date

    // HR window features (6 stats from 25s measurement)
    var hrrange: Double
    var hrvar: Double
    var hrstd: Double
    var hrmin: Double
    var hrmax: Double
    var hrkurt: Double
    var hrSampleCount: Int

    // Model outputs
    /// 0–10 stress level predicted by the population ensemble.
    var modelPrediction: Int
    /// Continuous ensemble probability in [0, 1].
    var ensembleRaw: Double
    var xgbProbability: Double
    var annNormalized: Double
    /// Distance from 0.5 decision boundary in [0.5, 1].
    var confidenceScore: Double

    // User subjective label
    /// User-perceived stress level (1–10).
    var userPrediction: Int

    // Context
    var responseLatencySeconds: Int
    var activityType: String
    var isTest: Bool

    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        features: StressHRFeatures,
        hrSampleCount: Int,
        modelPrediction: Int,
        ensembleRaw: Double,
        xgbProbability: Double,
        annNormalized: Double,
        confidenceScore: Double,
        userPrediction: Int,
        responseLatencySeconds: Int,
        activityType: String,
        isTest: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.hrrange = features.hrrange
        self.hrvar = features.hrvar
        self.hrstd = features.hrstd
        self.hrmin = features.hrmin
        self.hrmax = features.hrmax
        self.hrkurt = features.hrkurt
        self.hrSampleCount = hrSampleCount
        self.modelPrediction = modelPrediction
        self.ensembleRaw = ensembleRaw
        self.xgbProbability = xgbProbability
        self.annNormalized = annNormalized
        self.confidenceScore = confidenceScore
        self.userPrediction = userPrediction
        self.responseLatencySeconds = responseLatencySeconds
        self.activityType = activityType
        self.isTest = isTest
    }
}
