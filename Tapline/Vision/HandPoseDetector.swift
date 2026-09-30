import CoreImage
@preconcurrency import CoreVideo
import Observation
@preconcurrency import Vision

/// Runs Vision's hand pose request on camera frames and publishes smoothed results.
///
/// Two things matter here that are easy to skip and make the whole feature feel
/// broken if you do: (1) low-confidence points are dropped rather than drawn, and
/// (2) joint positions are smoothed frame-to-frame so the skeleton doesn't jitter.
@MainActor
@Observable
final class HandPoseDetector {
    private(set) var hands: [HandPose] = []

    /// Below this, Vision is guessing. Drawing guesses makes the overlay feel janky.
    private let jointConfidenceThreshold: Float = 0.3

    private let request: DetectHumanHandPoseRequest = {
        var request = DetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()

    private let smoother = HandPoseSmoother()

    /// Vision is not instant. Without this guard, frames queue up faster than
    /// they're processed and the overlay starts lagging visibly behind the hand.
    private var isProcessing = false

    func process(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        guard !isProcessing else { return }
        isProcessing = true

        Task {
            defer { isProcessing = false }
            do {
                let observations = try await request.perform(on: pixelBuffer, orientation: orientation)
                let poses = observations.compactMap { observation -> HandPose? in
                    let points = observation.allJoints()
                    guard !points.isEmpty else { return nil }

                    var joints: [HumanHandPoseObservation.JointName: CGPoint] = [:]
                    for jointName in HandPose.allJoints {
                        guard let point = points[jointName], point.confidence >= jointConfidenceThreshold else {
                            continue
                        }
                        joints[jointName] = point.location.cgPoint
                    }
                    guard !joints.isEmpty else { return nil }
                    return HandPose(
                        chirality: observation.chirality,
                        joints: joints,
                        confidence: observation.confidence
                    )
                }

                hands = smoother.smooth(poses)
            } catch {
                // No hand in frame is the common case, not an error worth surfacing.
            }
        }
    }
}
