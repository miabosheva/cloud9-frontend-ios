import Foundation

enum StressFeatureExtractor {
    static let minimumSampleCount = 10
    static let windowDuration: TimeInterval = 25.0

    /// Computes 6 HR stats from BPM samples in a 25s window.
    /// Formulas match `rolling_features()` in xalentis/stresshelpers (R `var`/`sd`/`e1071::kurtosis`).
    static func extract(from heartRates: [Double]) -> StressHRFeatures? {
        guard heartRates.count >= minimumSampleCount else { return nil }

        let hrMin = heartRates.min() ?? 0
        let hrMax = heartRates.max() ?? 0
        let hrRange = hrMax - hrMin
        let hrVar = sampleVariance(heartRates)
        let hrStd = sqrt(hrVar)
        let hrKurt = excessKurtosis(heartRates)

        return StressHRFeatures(
            hrrange: hrRange,
            hrvar: hrVar,
            hrstd: hrStd,
            hrmin: hrMin,
            hrmax: hrMax,
            hrkurt: hrKurt
        )
    }

    /// R default `var()` — sample variance (n − 1 denominator).
    private static func sampleVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSquaredDiffs = values.reduce(0.0) { $0 + pow($1 - mean, 2) }
        return sumSquaredDiffs / Double(values.count - 1)
    }

    /// `e1071::kurtosis` type 1 (excess kurtosis); NaN when variance ≈ 0 → 0.
    private static func excessKurtosis(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n > 1 else { return 0 }

        let mean = values.reduce(0, +) / n
        let diffs = values.map { $0 - mean }
        let m2 = diffs.reduce(0.0) { $0 + $1 * $1 } / n
        guard m2 > 1e-12 else { return 0 }

        let m4 = diffs.reduce(0.0) { $0 + pow($1, 4) } / n
        return m4 / (m2 * m2) - 3.0
    }
}
