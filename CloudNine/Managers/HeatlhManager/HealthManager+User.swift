import Foundation

extension HealthManager {
    func fetchLocalUserInfo() throws -> UserInfo {
        return try userPerssistanceService.loadUserInfo()
    }
}
