import Foundation

/// One detected tap: the moment the fingers came together, and how far they
/// had opened just before it.
public struct Tap: Sendable, Equatable {
    public let index: Int
    /// Timestamp of the closure (the local minimum), in seconds.
    public let time: Double
    /// Timestamp of the opening peak immediately before this closure.
    public let openPeakTime: Double
    /// Peak-to-closure distance in the normalized signal. This is the
    /// per-tap "range of motion" — the quantity that shrinks with
    /// bradykinesia.
    public let amplitude: Double
}

/// How the closed/open thresholds are chosen. Two strategies exist so the
/// benchmark can show, on the same real footage, what a naive detector
/// misses that an adaptive one catches.
public enum ThresholdStrategy: Sendable {
    /// Recomputes the closed/open band from a trailing window of the
    /// signal, so it tracks the trial's own amplitude as it shrinks. This
    /// is what the app uses.
    case adaptive(windowSeconds: Double = 2.5, lowerPercentile: Double = 0.25, upperPercentile: Double = 0.75)

    /// Sets the band once, from the first `calibrationSeconds` of the
    /// trial, and never revisits it — the way a simple "measure the first
    /// few taps and go" detector would work. Stands in for the naive
    /// baseline: it calibrates on the strong early taps and then misses the
    /// smaller, decremented ones later in the trial, which is exactly the
    /// clinically important part.
    case fixedCalibrated(calibrationSeconds: Double = 2.0, lowerPercentile: Double = 0.25, upperPercentile: Double = 0.75)
}

/// Hysteresis tap detector: a candidate tap opens when the signal crosses
/// above the upper band and closes (commits) when it later drops through the
/// lower band and rises back — never on a single threshold crossing, which
/// is what causes double-counting at the moment of contact (Vision's tips
/// jitter right as the fingers touch).
public enum TapDetector {
    public static func detect(
        signal: [SignalPoint],
        strategy: ThresholdStrategy,
        minGapSeconds: Double = 0.08,
        minSamplesForThreshold: Int = 5
    ) -> [Tap] {
        guard !signal.isEmpty else { return [] }
        let bands = thresholdBands(for: signal, strategy: strategy, minSamples: minSamplesForThreshold)

        enum Phase { case open, closed }
        var phase = Phase.open
        var openPeak = -Double.infinity
        var openPeakTime = signal.first?.timestamp ?? 0
        var closedMin = Double.infinity
        var closedMinTime = 0.0
        var taps: [Tap] = []
        var lastTapTime = -Double.infinity

        for (point, band) in zip(signal, bands) {
            guard let value = point.value, let (lower, upper) = band else { continue }

            switch phase {
            case .open:
                if value > openPeak {
                    openPeak = value
                    openPeakTime = point.timestamp
                }
                if value <= lower {
                    phase = .closed
                    closedMin = value
                    closedMinTime = point.timestamp
                }
            case .closed:
                if value < closedMin {
                    closedMin = value
                    closedMinTime = point.timestamp
                }
                if value >= upper {
                    if closedMinTime - lastTapTime >= minGapSeconds {
                        taps.append(Tap(
                            index: taps.count,
                            time: closedMinTime,
                            openPeakTime: openPeakTime,
                            amplitude: openPeak - closedMin
                        ))
                        lastTapTime = closedMinTime
                    }
                    phase = .open
                    openPeak = value
                    openPeakTime = point.timestamp
                }
            }
        }

        return taps
    }

    /// Per-sample (lower, upper) band, or nil where there isn't enough
    /// history yet to compute one. Computed causally (only past samples) so
    /// the adaptive strategy is a fair stand-in for something that could
    /// run live, not something that peeked at the whole trial.
    private static func thresholdBands(
        for signal: [SignalPoint],
        strategy: ThresholdStrategy,
        minSamples: Int
    ) -> [(Double, Double)?] {
        switch strategy {
        case .adaptive(let windowSeconds, let lowerP, let upperP):
            var windowValues: [(t: Double, v: Double)] = []
            return signal.map { point -> (Double, Double)? in
                if let v = point.value { windowValues.append((point.timestamp, v)) }
                let cutoff = point.timestamp - windowSeconds
                windowValues.removeAll { $0.t < cutoff }
                let values = windowValues.map(\.v)
                guard values.count >= minSamples else { return nil }
                return (percentile(values, lowerP), percentile(values, upperP))
            }

        case .fixedCalibrated(let calibrationSeconds, let lowerP, let upperP):
            let calibrationValues = signal
                .filter { $0.timestamp <= calibrationSeconds }
                .compactMap(\.value)
            guard calibrationValues.count >= minSamples else {
                return signal.map { _ in nil }
            }
            let band = (percentile(calibrationValues, lowerP), percentile(calibrationValues, upperP))
            return signal.map { _ in band }
        }
    }

    private static func percentile(_ values: [Double], _ p: Double) -> Double {
        let sorted = values.sorted()
        let index = Int((Double(sorted.count - 1) * p).rounded())
        return sorted[max(0, min(sorted.count - 1, index))]
    }
}
