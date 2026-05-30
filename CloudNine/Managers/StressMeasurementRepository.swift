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

        let dict: [String: Any] = [
            "timestamp": Timestamp(date: sample.timestamp),
            "hrrange": sample.hrrange,
            "hrvar": sample.hrvar,
            "hrstd": sample.hrstd,
            "hrmin": sample.hrmin,
            "hrmax": sample.hrmax,
            "hrkurt": sample.hrkurt,
            "hr_sample_count": sample.hrSampleCount,
            "model_prediction": sample.modelPrediction,
            "ensemble_raw": sample.ensembleRaw,
            "xgb_probability": sample.xgbProbability,
            "ann_normalized": sample.annNormalized,
            "confidence_score": sample.confidenceScore,
            "user_prediction": sample.userPrediction,
            "response_latency_seconds": sample.responseLatencySeconds,
            "activity_type": sample.activityType,
            "is_test": sample.isTest,
            "id": sample.id
        ]

        try await collection.document(sample.id).setData(dict, merge: false)
        print("✅ Saved stress measurement sample \(sample.id)")
    }
}
