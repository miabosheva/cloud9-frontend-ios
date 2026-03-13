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

        // Store a flat, analysis-friendly document using snake_case keys only.
        let dict: [String: Any] = [
            "timestamp": Timestamp(date: sample.timestamp),
            "hr_mean": sample.hrMean,
            "hr_std": sample.hrStd,
            "hrv_sdnn": sample.hrvSDNN,
            "lf_hf_ratio": sample.lfHfRatio,
            "model_prediction": sample.modelPrediction,
            "confidence_score": sample.confidenceScore,
            "user_prediction": sample.userPrediction,
            "phase": sample.phase,
            "response_latency_seconds": sample.responseLatencySeconds,
            "activity_type": sample.activityType,
            "is_test": sample.isTest,
            "id": sample.id
        ]

        try await collection.document(sample.id).setData(dict, merge: false)
        print("✅ Saved stress measurement sample \(sample.id)")
    }
}

