import Foundation

extension HealthManager {
    func fetchLocalUserInfo() throws -> UserInfo {
        return try userPersistenceService.loadUserInfo()
    }
}
