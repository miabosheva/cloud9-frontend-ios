import Foundation
import HealthKit

extension HealthKitManager {
    func setupDataObservationAndFetch() {
        guard authorizationStatus == .authorized else {
            print("Not authorized to set up data observations.")
            return
        }
                    startHeartRateObservation()
        //            startTemperatureObservations()
        //
        //            Task {
        //                try? await fetchSleepData(forDays: 7)
        //            }
    }
}
