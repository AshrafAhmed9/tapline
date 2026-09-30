import CoreGraphics
import Vision

/// Exponential moving average over joint positions, keyed by hand chirality.
///
/// Without this, Vision's per-frame noise makes the skeleton overlay visibly
/// vibrate even when the hand is still — the single fastest way to make this
/// feature look like a toy instead of a product.
final class HandPoseSmoother {
    /// Lower = smoother but laggier. 0.4 is a reasonable start for a 30fps feed.
    private let alpha: CGFloat = 0.4

    private var previous: [HumanHandPoseObservation.Chirality?: [HumanHandPoseObservation.JointName: CGPoint]] = [:]

    func smooth(_ poses: [HandPose]) -> [HandPose] {
        let seenChiralities = Set(poses.map(\.chirality))
        previous = previous.filter { seenChiralities.contains($0.key) }

        return poses.map { pose in
            var priorJoints = previous[pose.chirality] ?? [:]
            var smoothedJoints: [HumanHandPoseObservation.JointName: CGPoint] = [:]

            for (joint, newPoint) in pose.joints {
                if let priorPoint = priorJoints[joint] {
                    smoothedJoints[joint] = CGPoint(
                        x: priorPoint.x + alpha * (newPoint.x - priorPoint.x),
                        y: priorPoint.y + alpha * (newPoint.y - priorPoint.y)
                    )
                } else {
                    smoothedJoints[joint] = newPoint
                }
            }

            priorJoints = smoothedJoints
            previous[pose.chirality] = priorJoints

            return HandPose(chirality: pose.chirality, joints: smoothedJoints, confidence: pose.confidence)
        }
    }
}
