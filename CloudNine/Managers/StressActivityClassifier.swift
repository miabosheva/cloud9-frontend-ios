import Foundation
import HealthKit

/// Inferred activity during a 25s stress window using HealthKit motion proxies + HR stats.
/// HealthKit has no rest/work/exercise label — this is a heuristic for thesis context only.
enum StressActivityType: String, Codable {
    case rest = "rest"
    case work = "work"
    case exercise = "exercise"
    case unknown = "unknown"
}

enum StressActivityClassifier {
    static func classify(
        features: StressHRFeatures,
        stepsInWindow: Int,
        activeEnergyKcal: Double
    ) -> StressActivityType {
        let elevatedHR = features.hrmax >= 115 || features.hrrange >= 25
        let activeMotion = stepsInWindow >= 12 || activeEnergyKcal >= 4.0

        if activeMotion || elevatedHR && stepsInWindow >= 6 {
            return .exercise
        }

        let calmHR = features.hrmax <= 95 && features.hrrange <= 12
        let still = stepsInWindow <= 3 && activeEnergyKcal < 1.0

        if calmHR && still {
            return .rest
        }

        if stepsInWindow > 0 || features.hrmax > 100 {
            return .work
        }

        return calmHR ? .rest : .work
    }
}

enum StressMeasurementHealthKitContext {
    static func fetchWindowMetrics(
        healthStore: HKHealthStore,
        from start: Date,
        to end: Date
    ) async -> (steps: Int, activeEnergyKcal: Double) {
        async let steps = sumQuantity(
            healthStore: healthStore,
            identifier: .stepCount,
            unit: .count(),
            from: start,
            to: end
        )
        async let energy = sumQuantity(
            healthStore: healthStore,
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            from: start,
            to: end
        )

        let (stepTotal, kcal) = await (steps, energy)
        return (Int(stepTotal.rounded()), kcal)
    }

    private static func sumQuantity(
        healthStore: HKHealthStore,
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}
