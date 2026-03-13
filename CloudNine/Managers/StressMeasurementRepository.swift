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

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        let data = try encoder.encode(sample)
        guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UserManagerError.encodingFailed
        }

        // For analysis convenience, also mirror important fields in snake_case.
        dict["timestamp"] = Timestamp(date: sample.timestamp)
        dict["hr_mean"] = sample.hrMean
        dict["hr_std"] = sample.hrStd
        dict["hrv_sdnn"] = sample.hrvSDNN
        dict["lf_hf_ratio"] = sample.lfHfRatio
        dict["model_prediction"] = sample.modelPrediction
        dict["confidence_score"] = sample.confidenceScore
        dict["user_prediction"] = sample.userPrediction
        dict["phase"] = sample.phase
        dict["response_latency_seconds"] = sample.responseLatencySeconds
        dict["activity_type"] = sample.activityType
        dict["is_test"] = sample.isTest

        try await collection.document(sample.id).setData(dict, merge: true)
        print("✅ Saved stress measurement sample \(sample.id)")
    }
}

