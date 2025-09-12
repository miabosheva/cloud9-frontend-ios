import Foundation

@MainActor
@Observable
class UserSettingsViewModel {
    @ObservationIgnored private let service: UserPerssistanceServiceProtocol = UserPersistenceService()
    
    func saveUserInfo(_ userInfo: UserInfo) async throws {
        try await service.saveUserInfo(userInfo)
    }
}
