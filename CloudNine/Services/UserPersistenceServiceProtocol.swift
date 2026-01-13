import Foundation

protocol UserPersistenceServiceProtocol {
    func saveUserInfo(_ userInfo: UserInfo) async throws
    func loadUserInfo() throws -> UserInfo
}
