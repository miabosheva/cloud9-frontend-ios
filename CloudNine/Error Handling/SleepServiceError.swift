import Foundation

enum SleepServiceError: Error {
    case userNotAuthenticated
    case syncFailed(Error)
    case loadFailed(Error)
    case encodingFailed
    case decodingFailed
    
    var localizedDescription: String {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to sync data"
        case .syncFailed(let error):
            return "Failed to sync data: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load data: \(error.localizedDescription)"
        case .encodingFailed:
            return "Failed to encode data for storage"
        case .decodingFailed:
            return "Failed to decode data from storage"
        }
    }
}
