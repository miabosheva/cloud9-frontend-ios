import Foundation

enum HealthError: Error, LocalizedError {
    case failedToCreateType
    case noSamplesFound
    case healthKitNotAvailable
    case invalidSampleType
    case saveFailed
    case sleepLogExists
    case sleepLogOverlaps
    case userInfoNotFound
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateType:
            return "Failed to create HealthKit data type"
        case .noSamplesFound:
            return "No samples found"
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .invalidSampleType:
            return "Invalid sample type returned from HealthKit"
        case .saveFailed:
            return "Failed to save data to HealthKit"
        case .sleepLogExists:
            return "Sleep Log exists."
        case .sleepLogOverlaps:
            return "Sleep Log times overlap with another log."
        case .userInfoNotFound:
            return "Error while decoding user profile. User Info not found."
        }
    }
}
