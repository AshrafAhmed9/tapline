import CoreGraphics

/// A trial that fails the gate is refused, with a stated reason, rather than
/// scored anyway. Publishing a number computed from a hand that left the
/// frame halfway through would be worse than publishing nothing.
public enum QualityVerdict: Sendable, Equatable {
    case ok
    case refused(reason: String)
}

public enum QualityGate {
    public static func evaluate(
        samples: [TapSample],
        signal: [SignalPoint],
        taps: [Tap],
        droppedFrameFraction: Double,
        jointConfidenceThreshold: Float = 0.3
    ) -> QualityVerdict {
        guard !samples.isEmpty else {
            return .refused(reason: "No frames were captured.")
        }

        let missingOrLowConfidence = samples.filter {
            guard let confidence = $0.confidence else { return true }
            return confidence < jointConfidenceThreshold || !$0.hasFullHand
        }.count
        let missingFraction = Double(missingOrLowConfidence) / Double(samples.count)
        if missingFraction > 0.10 {
            return .refused(reason: "Your hand left the frame or wasn't clear enough for \(Int(missingFraction * 100))% of the trial. Try again with your hand steady and well lit.")
        }

        if droppedFrameFraction > 0.05 {
            return .refused(reason: "The camera dropped too many frames to measure this trial reliably.")
        }

        let scales: [Double] = samples.compactMap { sample -> Double? in
            guard let confidence = sample.confidence, confidence >= jointConfidenceThreshold,
                  let wrist = sample.wrist, let mcp = sample.middleMCP else { return nil }
            return Double(hypot(wrist.x - mcp.x, wrist.y - mcp.y))
        }
        if let variation = relativeVariation(scales), variation > 0.20 {
            return .refused(reason: "Your hand moved too much toward or away from the camera. Keep it steady, side-on, and the same distance away.")
        }

        if taps.count < 4 {
            return .refused(reason: "Fewer than 4 taps were detected. Tap wider and make sure your thumb and index finger are both visible.")
        }

        return .ok
    }

    private static func relativeVariation(_ values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        let sorted = values.sorted()
        let median = sorted[sorted.count / 2]
        guard median > 0 else { return nil }
        let p10 = sorted[Int(Double(sorted.count - 1) * 0.10)]
        let p90 = sorted[Int(Double(sorted.count - 1) * 0.90)]
        return (p90 - p10) / median
    }
}
