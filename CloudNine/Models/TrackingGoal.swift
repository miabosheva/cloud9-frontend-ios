import Foundation

enum TrackingGoal: String, CaseIterable, Codable {
    case motivation = "motivation"
    case health = "health"
    case accuracy = "accuracy"
    case balanced = "balanced"
    
    var displayName: String {
        switch self {
        case .motivation:
            return "Motivation"
        case .health:
            return "Health Tracking"
        case .accuracy:
            return "Accuracy"
        case .balanced:
            return "Balanced"
        }
    }
    
    var description: String {
        switch self {
        case .motivation:
            return "Encourage yourself to get enough sleep"
        case .health:
            return "Conservative health tracking"
        case .accuracy:
            return "Most accurate calculation"
        case .balanced:
            return "Balance of all approaches"
        }
    }
}
