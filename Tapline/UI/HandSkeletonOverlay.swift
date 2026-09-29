import SwiftUI
import Vision

/// The hero visual of the whole app: a live, glowing skeleton over the hand.
struct HandSkeletonOverlay: View {
    let hands: [HandPose]
    let layerHolder: PreviewLayerHolder

    var body: some View {
        Canvas { context, _ in
            for hand in hands {
                draw(hand: hand, in: &context)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(hand: HandPose, in context: inout GraphicsContext) {
        // Bones first, so joints render on top.
        for chain in HandPose.fingerChains {
            var previousPoint: CGPoint?
            for jointName in chain {
                guard let visionPoint = hand.joints[jointName],
                      let point = layerHolder.viewPoint(forVisionPoint: visionPoint) else {
                    previousPoint = nil
                    continue
                }
                if let previousPoint {
                    var path = Path()
                    path.move(to: previousPoint)
                    path.addLine(to: point)
                    context.stroke(path, with: .color(.boneColor), lineWidth: 3)
                }
                previousPoint = point
            }
        }

        for (jointName, visionPoint) in hand.joints {
            guard let point = layerHolder.viewPoint(forVisionPoint: visionPoint) else { continue }
            let radius: CGFloat = jointName == .wrist ? 7 : 5
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)

            context.fill(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(.jointGlow))
            context.fill(Path(ellipseIn: rect), with: .color(.jointColor))
        }
    }
}

private extension Color {
    static let jointColor = Color(red: 0.65, green: 0.85, blue: 1.0)
    static let jointGlow = Color(red: 0.65, green: 0.85, blue: 1.0).opacity(0.25)
    static let boneColor = Color(red: 0.55, green: 0.75, blue: 1.0).opacity(0.85)
}
