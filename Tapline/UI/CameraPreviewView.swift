import AVFoundation
import SwiftUI

/// Thin wrapper so SwiftUI can host an AVCaptureVideoPreviewLayer.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let layerHolder: PreviewLayerHolder

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        layerHolder.layer = view.previewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
