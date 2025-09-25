import Foundation
import Foundation

// TODO: - Define more sleep conditions
enum SleepConditions: CaseIterable, Hashable, Codable {
    case sleepApnea
    case insomnia
    case restlessLeg
    
    var displayName: String {
        switch self {
        case .sleepApnea: return "Sleep Apnea"
        case .insomnia: return "Insomnia"
        case .restlessLeg: return "Restless Leg"
        }
    }
    
    var description: String? {
        switch self {
        case .insomnia:
            return "Difficulty falling or staying asleep"
        case .sleepApnea:
            return "Breathing interruptions during sleep"
        case .restlessLeg:
            return "Uncomfortable leg sensations"
        }
    }
}
