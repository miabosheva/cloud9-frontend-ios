import Foundation

enum HealthError: String, Error, LocalizedError {
    case failedToCreateType
    case noSamplesFound
    case healthKitNotAvailable
    case invalidSampleType
    case saveFailed
    case sleepLogExists
    
    var localizedDescription: String {
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
        }
    }
}
