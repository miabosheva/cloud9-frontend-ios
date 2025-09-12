import Foundation

protocol UserPerssistanceServiceProtocol {
    func saveUserInfo(_ userInfo: UserInfo) async throws
    func loadUserInfo() throws -> UserInfo
}
