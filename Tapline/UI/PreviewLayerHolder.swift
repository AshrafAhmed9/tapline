import AVFoundation
import Observation

/// Lets the skeleton overlay convert Vision's normalized points into the same
/// aspect-fill coordinate space the camera preview is actually drawn in,
/// instead of re-deriving that math by hand and getting it subtly wrong.
@Observable
final class PreviewLayerHolder {
    weak var layer: AVCaptureVideoPreviewLayer?

    /// `point` is in Vision's space: normalized, origin bottom-left.
    func viewPoint(forVisionPoint point: CGPoint) -> CGPoint? {
        guard let layer else { return nil }
        let devicePoint = CGPoint(x: point.x, y: 1 - point.y)
        return layer.layerPointConverted(fromCaptureDevicePointOfInterest: devicePoint)
    }
}
