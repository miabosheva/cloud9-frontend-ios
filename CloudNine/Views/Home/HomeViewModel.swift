import Foundation

@MainActor
@Observable
class HomeViewModel {
    @ObservationIgnored private let service: UserPersistenceServiceProtocol = UserPersistenceService()
    
    func saveUserInfo(_ userInfo: UserInfo) async throws {
        try await service.saveUserInfo(userInfo)
    }
    
    func loadUserInfo() throws -> UserInfo {
        try service.loadUserInfo()
    }
}
