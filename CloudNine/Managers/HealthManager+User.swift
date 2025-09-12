import Foundation

extension HealthManager {
    private var userPerssistanceService: UserPerssistanceServiceProtocol {
        return UserPersistenceService()
    }
    
    func fetchLocalUserInfo() throws -> UserInfo {
        return try userPerssistanceService.loadUserInfo()
    }
}
