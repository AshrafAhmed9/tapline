import AVFoundation
@preconcurrency import CoreMedia
import TapCore
import UIKit

/// Owns the whole lifecycle of one visit to the app: camera permission,
/// countdown, recording, offline analysis, and the quality gate's verdict.
/// Everything downstream (the result screen, history) just reacts to
/// `phase`.
@MainActor
@Observable
final class TrialSession {
    enum Phase: Equatable {
        case requestingPermission
        case permissionDenied
        case cameraUnavailable(String)
        case pickingHand
        case settingUp(hand: TrialHand)
        case countdown(hand: TrialHand, secondsLeft: Int)
        case recording(hand: TrialHand, secondsLeft: Int)
        case analyzing
        case refused(reason: String)
        case result(metrics: TapMetricsResult, hand: TrialHand, videoURL: URL)
    }

    private(set) var phase: Phase = .requestingPermission

    /// The trial clip is kept only long enough to show the synced replay on
    /// the result screen — never persisted to history, and deleted the
    /// moment the user moves on. `Trial` (the SwiftData model) stores
    /// numbers only, never footage.
    private var pendingVideoURL: URL?

    let cameraController = CameraController()
    let liveDetector = HandPoseDetector()
    let previewLayerHolder = PreviewLayerHolder()

    private let recorder = TrialRecorder()
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let speech = AVSpeechSynthesizer()

    /// Only a throttle counter for the live overlay — benign to touch from
    /// the camera's background delivery queue without hopping actors.
    private nonisolated(unsafe) var frameCounter = 0

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await setUpCamera()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { await setUpCamera() } else { phase = .permissionDenied }
        default:
            phase = .permissionDenied
        }
    }

    private func setUpCamera() async {
        cameraController.onFrame = { [weak self] sampleBuffer in
            guard let self else { return }
            self.frameCounter += 1
            if self.frameCounter % 4 == 0, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                Task { @MainActor in
                    self.liveDetector.process(pixelBuffer, orientation: .up)
                }
            }
            Task { await self.recorder.append(sampleBuffer) }
        }
        do {
            try cameraController.configure()
            cameraController.start()
            phase = .pickingHand
        } catch {
            phase = .cameraUnavailable("Couldn't start the camera: \(error.localizedDescription)")
        }
    }

    func choose(hand: TrialHand) {
        phase = .settingUp(hand: hand)
    }

    func beginTrial(hand: TrialHand) {
        Task { await runCountdownAndRecord(hand: hand) }
    }

    func cancelAndReturnToPicker() {
        discardPendingVideo()
        phase = .pickingHand
    }

    func startOver() {
        discardPendingVideo()
        phase = .pickingHand
    }

    private func discardPendingVideo() {
        if let url = pendingVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        pendingVideoURL = nil
    }

    private func runCountdownAndRecord(hand: TrialHand) async {
        speak("Get ready")
        for second in stride(from: 3, through: 1, by: -1) {
            phase = .countdown(hand: hand, secondsLeft: second)
            haptics.impactOccurred()
            speak("\(second)")
            try? await Task.sleep(for: .seconds(1))
        }
        speak("Tap as wide and as fast as you can")

        do {
            _ = try await recorder.startNewTrial()
        } catch {
            phase = .cameraUnavailable("Couldn't start recording: \(error.localizedDescription)")
            return
        }

        let trialSeconds = 10
        for secondsLeft in stride(from: trialSeconds, through: 1, by: -1) {
            phase = .recording(hand: hand, secondsLeft: secondsLeft)
            try? await Task.sleep(for: .seconds(1))
        }

        phase = .analyzing
        await analyze(hand: hand)
    }

    private func analyze(hand: TrialHand) async {
        do {
            let (finishedURL, encoderDroppedFraction) = try await recorder.finish()
            let nominalFPS = cameraController.activeFrameRate
            let output = try await TrialAnalyzer.analyze(videoURL: finishedURL, nominalFPS: nominalFPS)
            let signal = TapSignalBuilder.build(from: output.samples)
            let taps = TapDetector.detect(signal: signal, strategy: .adaptive())
            let droppedFraction = max(output.droppedFrameFraction, encoderDroppedFraction)

            let verdict = QualityGate.evaluate(
                samples: output.samples,
                signal: signal,
                taps: taps,
                droppedFrameFraction: droppedFraction
            )

            switch verdict {
            case .refused(let reason):
                try? FileManager.default.removeItem(at: finishedURL)
                phase = .refused(reason: reason)
            case .ok:
                pendingVideoURL = finishedURL
                let duration = output.samples.last?.timestamp ?? Double(10)
                let metrics = TapMetricsResult.compute(taps: taps, durationSeconds: duration)
                phase = .result(metrics: metrics, hand: hand, videoURL: finishedURL)
            }
        } catch {
            phase = .cameraUnavailable("Couldn't analyze the trial: \(error.localizedDescription)")
        }
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        speech.speak(utterance)
    }
}
