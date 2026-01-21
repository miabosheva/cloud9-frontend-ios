import Foundation

/// Stress index result from ML model prediction
struct StressIndex: Codable {
    var value: Double // 0-100 stress index
    var timestamp: Date
    var confidence: Double? // Optional confidence score (0-1)
    
    init(value: Double, timestamp: Date = Date(), confidence: Double? = nil) {
        self.value = max(0, min(100, value)) // Clamp between 0-100
        self.timestamp = timestamp
        self.confidence = confidence
    }
    
    /// Stress level category based on index value
    var category: StressLevel {
        switch value {
        case 0..<25:
            return .low
        case 25..<50:
            return .moderate
        case 50..<75:
            return .high
        default:
            return .veryHigh
        }
    }
    
    var categoryColor: String {
        switch category {
        case .low:
            return "green"
        case .moderate:
            return "yellow"
        case .high:
            return "orange"
        case .veryHigh:
            return "red"
        }
    }
}

enum StressLevel: String, Codable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"
}
