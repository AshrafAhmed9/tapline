@preconcurrency import AVFoundation
@preconcurrency import CoreMedia
@preconcurrency import CoreVideo

/// Writes camera frames straight to an H.264 file as they arrive, so the
/// exact footage `TapCore.TrialAnalyzer` re-reads afterward is the exact
/// footage the user just recorded — no separate "analysis buffer" that
/// could drift from what's on screen.
///
/// An actor because frames arrive on the camera's dedicated video queue but
/// `finish()` is awaited from the UI; this serializes every mutation of the
/// writer without a manual lock.
actor TrialRecorder {
    enum RecorderError: Error {
        case notRecording
        case writerFailed(Error?)
    }

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var outputURL: URL?
    private var sessionStarted = false
    private(set) var totalFrameCount = 0
    private(set) var droppedFrameCount = 0

    /// Starts a new trial file. Call once per trial, before frames arrive.
    func startNewTrial() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        self.writer = writer
        self.outputURL = url
        self.input = nil
        self.sessionStarted = false
        self.totalFrameCount = 0
        self.droppedFrameCount = 0
        return url
    }

    /// Call for every frame while a trial is in progress. Safe to call when
    /// not recording (no-ops).
    func append(_ sampleBuffer: CMSampleBuffer) {
        guard let writer else { return }

        if input == nil {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                // Fast finger tips at 60fps blur badly at default bitrates;
                // this is the one setting that most affects whether the
                // offline analyzer can even see the fingertips separate.
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 10_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ],
            ]
            let newInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            newInput.expectsMediaDataInRealTime = true
            guard writer.canAdd(newInput) else { return }
            writer.add(newInput)
            input = newInput
            writer.startWriting()
        }

        guard let input else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if !sessionStarted {
            writer.startSession(atSourceTime: pts)
            sessionStarted = true
        }

        totalFrameCount += 1
        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        } else {
            // The encoder fell behind. Recorded, not silently ignored —
            // TapCore.QualityGate can refuse the trial if this gets high.
            droppedFrameCount += 1
        }
    }

    /// Finalizes the file and reports the fraction of frames the encoder
    /// couldn't keep up with.
    func finish() async throws -> (url: URL, droppedFraction: Double) {
        guard let writer, let outputURL else { throw RecorderError.notRecording }
        input?.markAsFinished()

        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }

        if writer.status == .failed {
            throw RecorderError.writerFailed(writer.error)
        }

        let fraction = totalFrameCount > 0 ? Double(droppedFrameCount) / Double(totalFrameCount) : 0
        self.writer = nil
        self.input = nil
        return (outputURL, fraction)
    }
}
