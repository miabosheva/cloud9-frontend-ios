import Foundation
import HealthKit
import Combine

extension HealthKitManager {

    func startHeartRateObservation() {
        guard let healthStore = healthStore else { return }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        // 1. Initial historical query (optional, but good for context)
        fetchLatestHeartRate() // Call this once to get the most recent value

        // 2. Observer Query for continuous updates
        heartRateQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
            guard let self = self else { return }

            if let error = error {
                print("Error observing heart rate: \(error.localizedDescription)")
                return
            }

            // A new heart rate sample has been saved. Fetch it.
            self.fetchLatestHeartRate()

            // Call the completion handler to let HealthKit know you've processed the update
            completionHandler()
        }

        healthStore.execute(heartRateQuery!)

        // Enable background delivery for more frequent updates (requires entitlement)
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if success {
                print("Heart rate background delivery enabled.")
            } else if let error = error {
                print("Failed to enable heart rate background delivery: \(error.localizedDescription)")
            }
        }
    }

    func stopHeartRateObservation() {
        guard let healthStore = healthStore, let query = heartRateQuery else { return }
        healthStore.stop(query)
        heartRateQuery = nil
        print("Heart rate observation stopped.")

        // Disable background delivery if no longer needed
        healthStore.disableBackgroundDelivery(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!) { success, error in
            if success {
                print("Heart rate background delivery disabled.")
            } else if let error = error {
                print("Failed to disable heart rate background delivery: \(error.localizedDescription)")
            }
        }
    }

    private func fetchLatestHeartRate() {
        guard let healthStore = healthStore else { return }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching latest heart rate: \(error.localizedDescription)")
                return
            }

            guard let mostRecentSample = samples?.first as? HKQuantitySample else {
                print("No heart rate samples found.")
                return
            }

            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let heartRateValue = mostRecentSample.quantity.doubleValue(for: heartRateUnit)

            DispatchQueue.main.async {
                self.latestHeartRate = heartRateValue
            }
        }
        healthStore.execute(query)
    }
}
