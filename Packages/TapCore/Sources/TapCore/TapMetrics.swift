import Foundation

/// The numbers a trial produces, matching the kinematic features clinicians
/// actually look at in the MDS-UPDRS finger-tapping item (rate, amplitude,
/// and — the sign of bradykinesia — decrement over the course of the trial).
public struct TapMetricsResult: Sendable, Equatable {
    public let tapCount: Int
    public let durationSeconds: Double
    public let tapsPerSecond: Double
    public let amplitudes: [Double]
    public let meanAmplitude: Double
    /// How much smaller the last taps are than the first, as a percentage.
    /// Positive means the taps shrank (the clinically meaningful direction).
    public let decrementPercent: Double
    /// Slope of amplitude vs. tap index, least-squares. Negative means
    /// shrinking over the whole trial, not just the tail.
    public let amplitudeSlope: Double
    /// Inter-tap intervals more than 2× the trial's median interval —
    /// freezing/hesitation moments, not just slow rhythm.
    public let hesitationCount: Int
    /// Coefficient of variation of inter-tap intervals: rhythm irregularity.
    public let rhythmCV: Double

    public static func compute(taps: [Tap], durationSeconds: Double) -> TapMetricsResult {
        let amplitudes = taps.map(\.amplitude)
        let mean = amplitudes.isEmpty ? 0 : amplitudes.reduce(0, +) / Double(amplitudes.count)

        let decrement: Double
        if amplitudes.count >= 6 {
            let first3 = Double(amplitudes.prefix(3).reduce(0, +)) / 3
            let last3 = Double(amplitudes.suffix(3).reduce(0, +)) / 3
            decrement = first3 > 0 ? (first3 - last3) / first3 * 100 : 0
        } else {
            decrement = 0
        }

        let slope = leastSquaresSlope(amplitudes)

        let intervals = zip(taps, taps.dropFirst()).map { $1.time - $0.time }
        let medianInterval = median(intervals)
        let hesitations = medianInterval > 0 ? intervals.filter { $0 > 2 * medianInterval }.count : 0
        let cv = coefficientOfVariation(intervals)

        return TapMetricsResult(
            tapCount: taps.count,
            durationSeconds: durationSeconds,
            tapsPerSecond: durationSeconds > 0 ? Double(taps.count) / durationSeconds : 0,
            amplitudes: amplitudes,
            meanAmplitude: mean,
            decrementPercent: decrement,
            amplitudeSlope: slope,
            hesitationCount: hesitations,
            rhythmCV: cv
        )
    }

    private static func leastSquaresSlope(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let n = Double(values.count)
        let xs = (0..<values.count).map(Double.init)
        let xMean = xs.reduce(0, +) / n
        let yMean = values.reduce(0, +) / n
        let numerator = zip(xs, values).reduce(0.0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) }
        let denominator = xs.reduce(0.0) { $0 + ($1 - xMean) * ($1 - xMean) }
        return denominator > 0 ? numerator / denominator : 0
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    private static func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance) / mean
    }
}
