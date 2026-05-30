import Foundation
import CoreML

struct StressEnsembleResult {
    let ensembleRaw: Double
    let xgbProbability: Double
    let annNormalized: Double
    let stressLevel: Int
}

private struct ANNScalerConfig: Decodable {
    let feature_order: [String]
    let mean: [Double]
    let std: [Double]
}

private struct EnsembleConfig: Decodable {
    let xgb_weight: Double
    let ann_weight: Double
    let ann_output_min: Double
    let ann_output_max: Double
}

enum StressEnsemblePredictorError: LocalizedError {
    case configNotFound(String)
    case configDecodeFailed(String)
    case modelLoadFailed(String)
    case scalerMismatch
    case predictionFailed(String)

    var errorDescription: String? {
        switch self {
        case .configNotFound(let name):
            return "Missing stress model config: \(name)"
        case .configDecodeFailed(let name):
            return "Failed to decode stress model config: \(name)"
        case .modelLoadFailed(let detail):
            return "Failed to load stress model: \(detail)"
        case .scalerMismatch:
            return "ANN scaler feature order does not match expected HR features"
        case .predictionFailed(let detail):
            return "Stress prediction failed: \(detail)"
        }
    }
}

/// Loads StressXGB + StressANN and blends outputs per deployment config.
final class StressEnsemblePredictor {
    private let xgbModel: StressXGB
    private let annModel: StressANN
    private let config: EnsembleConfig
    private let scaler: ANNScalerConfig

    private static let expectedFeatureOrder = [
        "hrrange", "hrvar", "hrstd", "hrmin", "hrmax", "hrkurt"
    ]

    init() throws {
        let mlConfig = MLModelConfiguration()
        mlConfig.computeUnits = .cpuAndGPU

        do {
            xgbModel = try StressXGB(configuration: mlConfig)
            annModel = try StressANN(configuration: mlConfig)
        } catch {
            throw StressEnsemblePredictorError.modelLoadFailed(error.localizedDescription)
        }

        config = try Self.loadConfig("ensemble_config", as: EnsembleConfig.self)
        scaler = try Self.loadConfig("ann_scaler", as: ANNScalerConfig.self)

        guard scaler.feature_order == Self.expectedFeatureOrder else {
            throw StressEnsemblePredictorError.scalerMismatch
        }
    }

    func predict(features: StressHRFeatures) async throws -> StressEnsembleResult {
        let raw = features.values

        let xgbInput = StressXGBInput(
            hrrange: raw[0],
            hrvar: raw[1],
            hrstd: raw[2],
            hrmin: raw[3],
            hrmax: raw[4],
            hrkurt: raw[5]
        )

        let scaled = zip(raw, zip(scaler.mean, scaler.std)).map { value, meanStd in
            let (mean, std) = meanStd
            return std > 0 ? (value - mean) / std : 0
        }

        let annInput = try StressANNInput(
            hrrange: Self.multiArray(scaled[0]),
            hrvar: Self.multiArray(scaled[1]),
            hrstd: Self.multiArray(scaled[2]),
            hrmin: Self.multiArray(scaled[3]),
            hrmax: Self.multiArray(scaled[4]),
            hrkurt: Self.multiArray(scaled[5])
        )

        do {
            let xgbOutput = try await xgbModel.prediction(input: xgbInput)
            let annOutput = try await annModel.prediction(input: annInput)

            let xgbProb = Self.sigmoid(xgbOutput.stress_probability)
            let annRaw = annOutput.stress_linear[0].doubleValue
            let annNorm = Self.normalizeANNOutput(
                annRaw,
                min: config.ann_output_min,
                max: config.ann_output_max
            )
            let ensembleRaw = config.xgb_weight * xgbProb + config.ann_weight * annNorm
            let stressLevel = Self.toStressLevel(ensembleRaw)

            return StressEnsembleResult(
                ensembleRaw: ensembleRaw,
                xgbProbability: xgbProb,
                annNormalized: annNorm,
                stressLevel: stressLevel
            )
        } catch {
            throw StressEnsemblePredictorError.predictionFailed(error.localizedDescription)
        }
    }

    static func normalizeANNOutput(_ raw: Double, min lo: Double, max hi: Double) -> Double {
        guard hi - lo > 1e-9 else { return 0 }
        return min(max((raw - lo) / (hi - lo), 0), 1)
    }

    /// CoreML XGB export returns pre-sigmoid logits; apply sigmoid for 0–1 probability.
    static func sigmoid(_ logit: Double) -> Double {
        guard logit < 20 else { return 1 }
        guard logit > -20 else { return 0 }
        return 1.0 / (1.0 + exp(-logit))
    }

    static func toStressLevel(_ ensembleRaw: Double) -> Int {
        Int(min(max(round(ensembleRaw * 10), 0), 10))
    }

    private static func multiArray(_ value: Double) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [1], dataType: .double)
        array[0] = NSNumber(value: value)
        return array
    }

    private static func loadConfig<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Stress")
            ?? Bundle.main.url(forResource: name, withExtension: "json") else {
            throw StressEnsemblePredictorError.configNotFound(name)
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw StressEnsemblePredictorError.configDecodeFailed(name)
        }
    }
}
