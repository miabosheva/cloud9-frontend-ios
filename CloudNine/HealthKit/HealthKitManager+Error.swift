import Foundation
import HealthKit

extension HealthKitManager {
    enum HealthKitError: Error, LocalizedError {
        case notAvailable
        case authorizationDenied
        case dataNotFound
        
        var errorDescription: String? {
            switch self {
            case .notAvailable: return "HealthKit is not available on this device."
            case .authorizationDenied: return "Authorization to access Health data was denied."
            case .dataNotFound: return "No Health data found for this query."
            }
        }
    }
}
