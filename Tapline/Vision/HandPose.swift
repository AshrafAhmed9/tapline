import CoreGraphics
import Vision

/// One hand's joints, in Vision's normalized coordinate space
/// (origin bottom-left, 0...1 on both axes).
struct HandPose {
    let chirality: HumanHandPoseObservation.Chirality?
    let joints: [HumanHandPoseObservation.JointName: CGPoint]
    let confidence: Float

    /// The 21 joints we care about, grouped finger by finger, wrist last.
    /// Order matters for drawing bones between them.
    static let fingerChains: [[HumanHandPoseObservation.JointName]] = [
        [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
        [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
        [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
        [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip],
    ]

    static let allJoints: [HumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]
}
