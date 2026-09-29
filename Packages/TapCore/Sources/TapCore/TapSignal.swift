import CoreGraphics
import Foundation

/// One point of the normalized thumb–index distance signal that everything
/// else (detection, metrics, the on-screen trace) is built from.
public struct SignalPoint: Sendable {
    public let timestamp: Double
    /// Thumb–index distance divided by the trial's hand scale. Nil means
    /// this frame's geometry was missing or unreliable — carried through
    /// rather than dropped, so gaps are visible instead of silently
    /// stitched over.
    public let value: Double?
}

/// Turns raw per-frame samples into the normalized signal `TapDetector` and
/// `TapMetrics` operate on.
///
/// Two decisions matter here and are easy to get wrong:
/// 1. **Normalize by the trial's median hand scale, not a per-frame scale.**
///    Wrist-to-middle-MCP shrinks when the hand tilts toward the camera, and
///    normalizing frame-by-frame would fake an amplitude decrement out of
///    pure rotation. One scale for the whole trial avoids that.
/// 2. **Median-filter over 3 frames and bridge gaps of 1–2 missing frames.**
///    Vision's tips jitter and briefly lose confidence exactly when the
///    fingers touch (occlusion at the tap itself), which is the one moment
///    the signal can't afford to be wrong.
public enum TapSignalBuilder {
    public static func build(from samples: [TapSample], jointConfidenceThreshold: Float = 0.3) -> [SignalPoint] {
        guard !samples.isEmpty else { return [] }

        let scale = handScale(of: samples, confidenceThreshold: jointConfidenceThreshold)

        let raw: [Double?] = samples.map { sample in
            guard let scale, scale > 0,
                  let confidence = sample.confidence, confidence >= jointConfidenceThreshold,
                  let thumb = sample.thumbTip, let index = sample.indexTip else {
                return nil
            }
            return distance(thumb, index) / scale
        }

        let filled = fillShortGaps(raw, maxGap: 2)
        let smoothed = medianFilter(filled, window: 3)

        return zip(samples, smoothed).map { SignalPoint(timestamp: $0.timestamp, value: $1) }
    }

    /// Median of wrist→middleMCP distance across every frame with a full,
    /// confident hand. Median (not mean) so a handful of bad frames can't
    /// drag the whole trial's normalization off.
    private static func handScale(of samples: [TapSample], confidenceThreshold: Float) -> Double? {
        let scales: [Double] = samples.compactMap { sample in
            guard let confidence = sample.confidence, confidence >= confidenceThreshold,
                  let wrist = sample.wrist, let mcp = sample.middleMCP else { return nil }
            return distance(wrist, mcp)
        }
        guard !scales.isEmpty else { return nil }
        return scales.sorted()[scales.count / 2]
    }

    /// Linear-interpolates runs of at most `maxGap` consecutive missing
    /// values between two known neighbors. Longer runs stay nil — that's a
    /// real dropout (hand left frame, tracking lost), not tap-closure noise.
    private static func fillShortGaps(_ values: [Double?], maxGap: Int) -> [Double?] {
        var result = values
        var i = 0
        while i < result.count {
            guard result[i] == nil else { i += 1; continue }
            var j = i
            while j < result.count, result[j] == nil { j += 1 }
            let gapLength = j - i
            if i > 0, j < result.count, gapLength <= maxGap,
               let before = result[i - 1], let after = result[j] {
                for k in i..<j {
                    let t = Double(k - i + 1) / Double(gapLength + 1)
                    result[k] = before + (after - before) * t
                }
            }
            i = j
        }
        return result
    }

    private static func medianFilter(_ values: [Double?], window: Int) -> [Double?] {
        let half = window / 2
        return values.indices.map { i -> Double? in
            let lo = max(0, i - half)
            let hi = min(values.count - 1, i + half)
            let neighborhood = values[lo...hi].compactMap { $0 }
            guard values[i] != nil, !neighborhood.isEmpty else { return nil }
            let sorted = neighborhood.sorted()
            return sorted[sorted.count / 2]
        }
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        Double(hypot(a.x - b.x, a.y - b.y))
    }
}
