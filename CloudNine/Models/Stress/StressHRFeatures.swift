import Foundation

/// Six HR window statistics matching Vos et al. / StressData column order.
struct StressHRFeatures: Equatable, Codable {
    let hrrange: Double
    let hrvar: Double
    let hrstd: Double
    let hrmin: Double
    let hrmax: Double
    let hrkurt: Double

    /// Training / CoreML feature order: hrrange, hrvar, hrstd, hrmin, hrmax, hrkurt
    var values: [Double] {
        [hrrange, hrvar, hrstd, hrmin, hrmax, hrkurt]
    }
}
