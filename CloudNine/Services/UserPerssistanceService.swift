import Foundation

final class UserPersistenceService: UserPerssistanceServiceProtocol {
    private let key = "user_info"
    private let defaults = UserDefaults.standard
    
    func saveUserInfo(_ userInfo: UserInfo) async throws {
        let data = try JSONEncoder().encode(userInfo)
        defaults.set(data, forKey: key)
    }
    
    func loadUserInfo() throws -> UserInfo {
        guard let data = defaults.data(forKey: key),
              let userInfo = try? JSONDecoder().decode(UserInfo.self, from: data) else {
            throw HealthError.userInfoNotFound
        }
        return userInfo
    }
}
