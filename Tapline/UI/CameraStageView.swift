import SwiftUI

/// The live camera feed plus the hand skeleton, shared by setup, countdown
/// and recording — only the overlay content on top changes between them.
struct CameraStageView<Overlay: View>: View {
    let session: TrialSession
    @ViewBuilder let overlay: () -> Overlay

    var body: some View {
        ZStack {
            CameraPreviewView(session: session.cameraController.session, layerHolder: session.previewLayerHolder)
                .ignoresSafeArea()
            HandSkeletonOverlay(hands: session.liveDetector.hands, layerHolder: session.previewLayerHolder)
                .ignoresSafeArea()
            overlay()
        }
    }
}
