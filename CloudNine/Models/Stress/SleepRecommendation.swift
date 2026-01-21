import Foundation

/// Sleep optimization recommendations from ML model
struct SleepOptimizationRecommendation: Codable {
    var recommendedBedtime: Date
    var recommendedWakeTime: Date
    var recommendedDuration: Double // hours
    var reasoning: String? // Optional explanation
    var confidence: Double? // Optional confidence score (0-1)
    var timestamp: Date
    
    init(
        recommendedBedtime: Date,
        recommendedWakeTime: Date,
        recommendedDuration: Double,
        reasoning: String? = nil,
        confidence: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.recommendedBedtime = recommendedBedtime
        self.recommendedWakeTime = recommendedWakeTime
        self.recommendedDuration = recommendedDuration
        self.reasoning = reasoning
        self.confidence = confidence
        self.timestamp = timestamp
    }
    
    var formattedBedtime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: recommendedBedtime)
    }
    
    var formattedWakeTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: recommendedWakeTime)
    }
    
    var formattedDuration: String {
        let hours = Int(recommendedDuration)
        let minutes = Int((recommendedDuration - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }
}
