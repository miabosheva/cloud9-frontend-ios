import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Persists stress measurement samples for the thesis experiment.
actor StressMeasurementRepository {
    private let db = Firestore.firestore()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    private var samplesCollection: CollectionReference? {
        guard let userId else { return nil }
        return db
            .collection("users")
            .document(userId)
            .collection("measurement_samples")
    }

    func save(_ sample: StressMeasurementSample) async throws {
        guard let collection = samplesCollection else {
            throw UserManagerError.userNotAuthenticated
        }

        var dict: [String: Any] = [
            "timestamp": Timestamp(date: sample.timestamp),
            "hr_values": sample.hrValues,
            "hrrange": sample.hrrange,
            "hrvar": sample.hrvar,
            "hrstd": sample.hrstd,
            "hrmin": sample.hrmin,
            "hrmax": sample.hrmax,
            "hrkurt": sample.hrkurt,
            "hr_sample_count": sample.hrSampleCount,
            "steps_in_window": sample.stepsInWindow,
            "active_energy_kcal": sample.activeEnergyKcal,
            "model_prediction": sample.modelPrediction,
            "ensemble_raw": sample.ensembleRaw,
            "xgb_probability": sample.xgbProbability,
            "ann_normalized": sample.annNormalized,
            "confidence_score": sample.confidenceScore,
            "user_rating_status": sample.userRatingStatus.rawValue,
            "activity_type": sample.activityType,
            "is_test": sample.isTest,
            "id": sample.id
        ]

        if let started = sample.measurementStartedAt {
            dict["measurement_started_at"] = Timestamp(date: started)
        }

        if let userPrediction = sample.userPrediction {
            dict["user_prediction"] = userPrediction
        }

        if let latency = sample.responseLatencySeconds {
            dict["response_latency_seconds"] = latency
        }

        try await collection.document(sample.id).setData(dict, merge: false)
        print("✅ Saved stress measurement sample \(sample.id) (\(sample.userRatingStatus.rawValue))")
    }
}
