import CoreGraphics

/// One video frame's hand geometry, already reduced to the four points the
/// tapping signal needs. Produced by `TrialAnalyzer` (from a live camera feed
/// or a video file — same struct either way, which is what lets `tapbench`
/// reuse the exact analysis the app runs).
public struct TapSample: Sendable {
    /// Seconds since the trial started.
    public let timestamp: Double
    public let thumbTip: CGPoint?
    public let indexTip: CGPoint?
    public let wrist: CGPoint?
    public let middleMCP: CGPoint?
    /// Vision's lowest confidence among the four points above. Nil if no
    /// hand was found in this frame at all.
    public let confidence: Float?

    public init(
        timestamp: Double,
        thumbTip: CGPoint?,
        indexTip: CGPoint?,
        wrist: CGPoint?,
        middleMCP: CGPoint?,
        confidence: Float?
    ) {
        self.timestamp = timestamp
        self.thumbTip = thumbTip
        self.indexTip = indexTip
        self.wrist = wrist
        self.middleMCP = middleMCP
        self.confidence = confidence
    }

    /// A frame only carries a usable geometry if all four points landed.
    var hasFullHand: Bool {
        thumbTip != nil && indexTip != nil && wrist != nil && middleMCP != nil
    }
}
