@preconcurrency import AVFoundation
import CoreMedia
import UIKit

/// Owns the capture session and hands raw frames to whoever wants them.
/// Deliberately dumb: no Vision code here, so it stays testable and swappable.
final class CameraController: NSObject {
    let session = AVCaptureSession()

    private let videoQueue = DispatchQueue(label: "com.tapline.camera.video")
    private let videoOutput = AVCaptureVideoDataOutput()

    /// Called on `videoQueue` for every frame. Keep this fast.
    var onFrame: ((CMSampleBuffer) -> Void)?

    /// The frame rate `configure()` actually locked the device to. Taps
    /// happen at 3-5Hz; 30fps leaves only 6-10 samples per tap, which is too
    /// coarse to see the closure cleanly — this is why we hunt for 60fps
    /// instead of trusting `.high` (which tops out at 30 on the front
    /// camera). Read by `TrialRecorder`/`TrialAnalyzer` to estimate dropped
    /// frames.
    private(set) var activeFrameRate: Double = 30

    enum SetupError: Error {
        case noFrontCamera
        case cannotAddInput
        case cannotAddOutput
    }

    func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw SetupError.noFrontCamera
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw SetupError.cannotAddInput }
        session.addInput(input)

        session.sessionPreset = .inputPriority
        activeFrameRate = configureHighestFrameRate(on: device, target: 60)

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput) else { throw SetupError.cannotAddOutput }
        session.addOutput(videoOutput)

        // Front camera feed is mirrored by default; un-mirror so "raise your right
        // hand" in the mirror matches what the model and the user both expect.
        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
    }

    /// Picks the highest-resolution format that supports at least
    /// `target` fps, and locks the device to the highest frame rate that
    /// format supports (capped at `target`). Falls back to whatever the
    /// device's current format allows if nothing reaches `target` — some
    /// older front cameras cap out at 30fps, and the app should degrade
    /// rather than throw.
    private func configureHighestFrameRate(on device: AVCaptureDevice, target: Double) -> Double {
        let candidates = device.formats.filter { format in
            format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= target }
        }
        // Cap resolution: the offline analyzer runs Vision on every frame of
        // a 600+ frame clip, and a 4K-class front-camera format would make
        // that take far longer than the trial itself. 1080p is plenty for
        // finger-tip tracking.
        let maxPixels = 1920 * 1440
        let withinBudget = candidates.filter {
            let d = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            return Int(d.width) * Int(d.height) <= maxPixels
        }
        let pool = withinBudget.isEmpty ? candidates : withinBudget
        let bestFormat = pool.max {
            let a = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            let b = CMVideoFormatDescriptionGetDimensions($1.formatDescription)
            return (a.width * a.height) < (b.width * b.height)
        } ?? device.activeFormat

        guard let range = bestFormat.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate }) else {
            return 30
        }
        let fps = min(target, range.maxFrameRate)

        do {
            try device.lockForConfiguration()
            device.activeFormat = bestFormat
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.unlockForConfiguration()
            return fps
        } catch {
            return 30
        }
    }

    func start() {
        guard !session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer)
    }
}
