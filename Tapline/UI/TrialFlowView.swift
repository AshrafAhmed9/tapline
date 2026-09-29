import SwiftData
import SwiftUI
import UIKit

/// Drives the whole "take a test" experience off `TrialSession.phase`.
/// Every phase is a dumb, stateless view — all the logic lives in the
/// session so this file stays a straightforward switch.
struct TrialFlowView: View {
    @State private var session = TrialSession()
    @Environment(\.modelContext) private var modelContext

    @State private var pendingDoseState: DoseState = .unsure
    @State private var pendingMinutes: Int?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch session.phase {
            case .requestingPermission:
                ProgressView().tint(.white)

            case .permissionDenied:
                PermissionDeniedView()

            case .cameraUnavailable(let message):
                StatusMessageView(systemImage: "exclamationmark.triangle", message: message) {
                    Button("Try again") { Task { await session.start() } }
                        .buttonStyle(.bordered)
                        .tint(.white)
                }

            case .pickingHand:
                HandPickerView { hand, doseState, minutes in
                    pendingDoseState = doseState
                    pendingMinutes = minutes
                    session.choose(hand: hand)
                }
                .background(Color(.systemBackground))

            case .settingUp(let hand):
                CameraStageView(session: session) {
                    SetupOverlay(
                        hand: hand,
                        onReady: { session.beginTrial(hand: hand) },
                        onCancel: { session.cancelAndReturnToPicker() }
                    )
                }

            case .countdown(_, let secondsLeft):
                CameraStageView(session: session) {
                    BigNumberOverlay(text: "\(secondsLeft)", subtitle: "Get ready")
                }

            case .recording(_, let secondsLeft):
                CameraStageView(session: session) {
                    BigNumberOverlay(text: "\(secondsLeft)", subtitle: "Tap as wide and as fast as you can", tint: .red)
                }

            case .analyzing:
                VStack(spacing: 16) {
                    ProgressView().tint(.white).controlSize(.large)
                    Text("Analyzing your tapping…").foregroundStyle(.white)
                }

            case .refused(let reason):
                StatusMessageView(systemImage: "hand.raised.slash", message: reason) {
                    Button("Try again") { session.startOver() }
                        .buttonStyle(.borderedProminent)
                }

            case .result(let metrics, let hand, let videoURL):
                TrialResultView(
                    metrics: metrics,
                    hand: hand,
                    videoURL: videoURL,
                    onSave: {
                        let trial = Trial(hand: hand, doseState: pendingDoseState, minutesSinceLastDose: pendingMinutes, metrics: metrics)
                        modelContext.insert(trial)
                        session.startOver()
                    },
                    onDiscard: { session.startOver() }
                )
            }
        }
        .task { await session.start() }
    }
}

private struct SetupOverlay: View {
    let hand: TrialHand
    let onReady: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white, .black.opacity(0.4))
                }
                Spacer()
            }
            .padding()

            Spacer()

            VStack(spacing: 16) {
                Text("Testing your \(hand.label.lowercased())")
                    .font(.headline)
                Text("Center your hand, side-on to the camera, with your thumb and index finger visible.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button("I'm ready", action: onReady)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(24)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

private struct BigNumberOverlay: View {
    let text: String
    let subtitle: String
    var tint: Color = .white

    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(.default, value: text)
            Text(subtitle)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.bottom, 60)
    }
}

private struct StatusMessageView<Actions: View>: View {
    let systemImage: String
    let message: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.white)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            actions()
        }
        .padding(32)
    }
}

private struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.slash")
                .font(.largeTitle)
            Text("Tapline needs the camera to see your hand.")
                .multilineTextAlignment(.center)
            Text("Nothing is ever uploaded — analysis happens on your iPhone and the clip is deleted right after.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .padding()
    }
}

#Preview {
    TrialFlowView()
        .modelContainer(for: Trial.self, inMemory: true)
}
