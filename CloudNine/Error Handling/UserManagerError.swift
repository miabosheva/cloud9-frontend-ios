import Foundation

enum UserManagerError: Error {
    case userNotAuthenticated
    case userInfoNotFound
    case invalidUserInfoData
    case encodingFailed
    case fetchFailed(Error)
    case saveFailed(Error)
    case updateFailed(Error)
    case createUserFailed(Error)
    case deleteFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated"
        case .userInfoNotFound:
            return "User information not found"
        case .invalidUserInfoData:
            return "Invalid user information data format"
        case .encodingFailed:
            return "Failed to encode user information"
        case .fetchFailed(let error):
            return "Failed to fetch user info: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save user info: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update user info: \(error.localizedDescription)"
        case .createUserFailed(let error):
            return "Failed to create user document: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete user info: \(error.localizedDescription)"
        }
    }
}
