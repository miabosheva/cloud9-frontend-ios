import Foundation

/// Whether the user submitted a subjective 1–10 rating after measurement.
enum UserRatingStatus: String, Codable {
    /// User tapped Submit on the rating sheet.
    case submitted = "submitted"
    /// User tapped Cancel / skipped the rating sheet (model row still saved).
    case skipped = "skipped"
}

/// Single stress measurement sample stored in Firestore.
struct StressMeasurementSample: Codable, Identifiable {
    var id: String
    var timestamp: Date
    var measurementStartedAt: Date?

    /// Raw BPM samples from the 25s window (sampled ~1 Hz from HealthKit + Watch).
    var hrValues: [Double]

    // HR window features (6 stats from 25s measurement)
    var hrrange: Double
    var hrvar: Double
    var hrstd: Double
    var hrmin: Double
    var hrmax: Double
    var hrkurt: Double
    var hrSampleCount: Int

    // HealthKit context for the window
    var stepsInWindow: Int
    var activeEnergyKcal: Double

    // Model outputs
    var modelPrediction: Int
    var ensembleRaw: Double
    var xgbProbability: Double
    var annNormalized: Double
    var confidenceScore: Double

    // User subjective label — nil only when user_rating_status == .skipped
    var userPrediction: Int?
    var userRatingStatus: UserRatingStatus

    // Context
    var activityType: String
    var responseLatencySeconds: Int?
    var isTest: Bool
    var watchWorkoutStarted: Bool

    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        measurementStartedAt: Date? = nil,
        hrValues: [Double],
        features: StressHRFeatures,
        hrSampleCount: Int,
        stepsInWindow: Int,
        activeEnergyKcal: Double,
        modelPrediction: Int,
        ensembleRaw: Double,
        xgbProbability: Double,
        annNormalized: Double,
        confidenceScore: Double,
        userPrediction: Int?,
        userRatingStatus: UserRatingStatus,
        responseLatencySeconds: Int?,
        activityType: StressActivityType,
        isTest: Bool,
        watchWorkoutStarted: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.measurementStartedAt = measurementStartedAt
        self.hrValues = hrValues
        self.hrrange = features.hrrange
        self.hrvar = features.hrvar
        self.hrstd = features.hrstd
        self.hrmin = features.hrmin
        self.hrmax = features.hrmax
        self.hrkurt = features.hrkurt
        self.hrSampleCount = hrSampleCount
        self.stepsInWindow = stepsInWindow
        self.activeEnergyKcal = activeEnergyKcal
        self.modelPrediction = modelPrediction
        self.ensembleRaw = ensembleRaw
        self.xgbProbability = xgbProbability
        self.annNormalized = annNormalized
        self.confidenceScore = confidenceScore
        self.userPrediction = userPrediction
        self.userRatingStatus = userRatingStatus
        self.responseLatencySeconds = responseLatencySeconds
        self.activityType = activityType.rawValue
        self.isTest = isTest
        self.watchWorkoutStarted = watchWorkoutStarted
    }
}
