import Foundation
import HealthKit

extension HealthKitManager {
    enum AuthorizationStatus {
        case unknown            // Initial state
        case notAvailableOnDevice // HealthKit is not supported
        case authorized         // All required permissions granted
        case requiredPermissionsMissing // Some required permissions are missing or denied
    }
    
    func requestAuthorization() async throws {
        let typesToShare: Set<HKSampleType> = []
        
        guard let healthStore = self.healthStore else {
            throw HealthKitError.notAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: requiredReadTypes)
        
//        await MainActor.run {
//            checkAllAuthorizationStatuses()
//        }
        
        print("requesting...")
    }
    
    func checkAllAuthorizationStatuses() {
        //this checks writing authorization, we only need reading authorization
        // TODO: - Update in the future to handle this?
        guard let healthStore = healthStore else {
            authorizationStatus = .notAvailableOnDevice
            return
        }
        
        var allAuthorized = true
        for type in requiredReadTypes {
            let status = healthStore.authorizationStatus(for: type)
            if status != .sharingAuthorized {
                allAuthorized = false
                break
            }
        }
        
        if allAuthorized {
            authorizationStatus = .authorized
        } else {
            authorizationStatus = .requiredPermissionsMissing
        }
    }
}
