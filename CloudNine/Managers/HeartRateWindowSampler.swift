import Foundation
import HealthKit

/// Observes and queries heart rate samples during a stress measurement window.
@MainActor
final class HeartRateWindowSampler {
    private let healthStore: HKHealthStore
    private var observerQuery: HKObserverQuery?
    private var onSample: ((Double, Date) -> Void)?

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func start(onSample: @escaping (Double, Date) -> Void) {
        stop()
        self.onSample = onSample

        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            if let error {
                print("❌ HR observer error: \(error.localizedDescription)")
                return
            }
            Task { @MainActor in
                await self?.fetchLatestSample()
            }
        }
        observerQuery = query
        healthStore.execute(query)

        Task {
            await fetchLatestSample()
        }
    }

    func stop() {
        if let observerQuery {
            healthStore.stop(observerQuery)
        }
        observerQuery = nil
        onSample = nil
    }

    private func fetchLatestSample() async {
        guard let sample = await Self.fetchLatestWatchSample(healthStore: healthStore, within: 15) else { return }
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let bpm = sample.quantity.doubleValue(for: hrUnit)
        guard bpm > 0 else { return }
        onSample?(bpm, sample.endDate)
    }

    // MARK: - Static queries

    static func fetchLatestWatchHeartRate(healthStore: HKHealthStore, within seconds: TimeInterval) async -> Double? {
        guard let sample = await fetchLatestWatchSample(healthStore: healthStore, within: seconds) else { return nil }
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let bpm = sample.quantity.doubleValue(for: hrUnit)
        return bpm > 0 ? bpm : nil
    }

    static func fetchRecentWatchHeartRates(healthStore: HKHealthStore, within seconds: TimeInterval) async -> [Double] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }

        let end = Date()
        let start = end.addingTimeInterval(-seconds)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, _ in
                let hrUnit = HKUnit.count().unitDivided(by: .minute())
                let values = (samples as? [HKQuantitySample])?
                    .filter { isFromAppleWatch($0) }
                    .map { $0.quantity.doubleValue(for: hrUnit) }
                    .filter { $0 > 0 } ?? []
                continuation.resume(returning: values)
            }
            healthStore.execute(query)
        }
    }

    private static func fetchLatestWatchSample(healthStore: HKHealthStore, within seconds: TimeInterval) async -> HKQuantitySample? {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }

        let end = Date()
        let start = end.addingTimeInterval(-seconds)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 20,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let watchSample = (samples as? [HKQuantitySample])?.first { isFromAppleWatch($0) }
                continuation.resume(returning: watchSample)
            }
            healthStore.execute(query)
        }
    }

    static func isFromAppleWatch(_ sample: HKQuantitySample) -> Bool {
        if let deviceName = sample.device?.name,
           deviceName.localizedCaseInsensitiveContains("Watch") {
            return true
        }
        let bundle = sample.sourceRevision.source.bundleIdentifier.lowercased()
        return bundle.contains("watch")
    }
}
