import AVFoundation
import CoreGraphics
import CoreMedia
import Vision

/// Reads every frame of a saved trial video and turns it into `TapSample`s.
///
/// This is the one piece of analysis code the iPhone app and the `tapbench`
/// command-line benchmark both call — the same function that scores a live
/// trial on-device also scores the 234 clinical videos in the benchmark, so
/// there's no separate "demo path" and "real path" to drift apart.
///
/// Deliberately **not** the live-preview detector: no frame dropping, no
/// smoothing, `maximumHandCount = 1` (a tapping trial has exactly one hand
/// in frame), and it runs to completion rather than best-effort per frame.
public enum TrialAnalyzer {
    public struct Output: Sendable {
        public let samples: [TapSample]
        /// Estimated fraction of frames the capture pipeline lost, from
        /// comparing the decoded frame count against what `nominalFPS` over
        /// the clip's duration implies. Zero for videos read from disk with
        /// no live-capture step upstream (e.g. dataset clips).
        public let droppedFrameFraction: Double
    }

    public enum AnalyzerError: Error {
        case noVideoTrack
        case cannotStartReading
    }

    public static func analyze(
        videoURL: URL,
        orientation: CGImagePropertyOrientation = .up,
        jointConfidenceThreshold: Float = 0.3,
        nominalFPS: Double? = nil
    ) async throws -> Output {
        let asset = AVURLAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw AnalyzerError.noVideoTrack
        }
        let duration = try await asset.load(.duration).seconds

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AnalyzerError.cannotStartReading }
        reader.add(output)
        guard reader.startReading() else { throw AnalyzerError.cannotStartReading }

        var request = DetectHumanHandPoseRequest()
        request.maximumHandCount = 1

        var samples: [TapSample] = []
        var firstPTS: Double?

        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            if firstPTS == nil { firstPTS = pts }
            let timestamp = pts - (firstPTS ?? pts)

            let observations = (try? await request.perform(on: pixelBuffer, orientation: orientation)) ?? []
            samples.append(sample(at: timestamp, from: observations.first, confidenceThreshold: jointConfidenceThreshold))
        }

        let droppedFraction: Double
        if let nominalFPS, duration > 0 {
            let expected = duration * nominalFPS
            droppedFraction = expected > 0 ? max(0, 1 - Double(samples.count) / expected) : 0
        } else {
            droppedFraction = 0
        }

        return Output(samples: samples, droppedFrameFraction: droppedFraction)
    }

    private static func sample(
        at timestamp: Double,
        from observation: VNHumanHandPoseObservation?,
        confidenceThreshold: Float
    ) -> TapSample {
        guard let observation, let points = try? observation.allJoints() else {
            return TapSample(timestamp: timestamp, thumbTip: nil, indexTip: nil, wrist: nil, middleMCP: nil, confidence: nil)
        }

        func point(_ joint: VNHumanHandPoseObservation.JointName) -> (CGPoint, Float)? {
            guard let p = points[joint], p.confidence >= confidenceThreshold else { return nil }
            return (p.location, p.confidence)
        }

        let thumb = point(.thumbTip)
        let index = point(.indexTip)
        let wrist = point(.wrist)
        let mcp = point(.middleMCP)

        let confidences = [thumb?.1, index?.1, wrist?.1, mcp?.1].compactMap { $0 }
        let confidence = confidences.isEmpty ? nil : confidences.min()

        return TapSample(
            timestamp: timestamp,
            thumbTip: thumb?.0,
            indexTip: index?.0,
            wrist: wrist?.0,
            middleMCP: mcp?.0,
            confidence: confidence
        )
    }
}
