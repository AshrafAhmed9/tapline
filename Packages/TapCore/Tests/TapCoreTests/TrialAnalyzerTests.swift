import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import Testing
@testable import TapCore

/// The synthetic-signal tests in `TapMetricsTests` never touch
/// `AVAssetReader` or real encoded video, so a timestamp or pixel-format bug
/// in `TrialAnalyzer` itself could hide behind an otherwise-green suite.
/// This writes a real (handless) .mov with AVAssetWriter and reads it back
/// through the actual analyzer, checking frame count and timing survive a
/// real encode/decode round trip.
struct TrialAnalyzerTests {
    @Test func readsBackCorrectFrameCountAndTimestamps() async throws {
        let fps: Int32 = 30
        let durationSeconds = 2
        let expectedFrameCount = Int(fps) * durationSeconds
        let width = 320, height = 240

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for i in 0..<expectedFrameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            guard let pool = adaptor.pixelBufferPool else { break }
            var pixelBufferOut: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBufferOut)
            guard let pixelBuffer = pixelBufferOut else { continue }
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
                memset(base, i % 2 == 0 ? 0 : 255, CVPixelBufferGetBytesPerRow(pixelBuffer) * height)
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
        }
        input.markAsFinished()
        await withCheckedContinuation { continuation in writer.finishWriting { continuation.resume() } }
        #expect(writer.status == .completed)

        let output = try await TrialAnalyzer.analyze(videoURL: url, nominalFPS: Double(fps))

        #expect(abs(output.samples.count - expectedFrameCount) <= 1)
        #expect((output.samples.first?.timestamp ?? -1) < 0.01)
        let expectedLast = Double(expectedFrameCount - 1) / Double(fps)
        #expect(abs((output.samples.last?.timestamp ?? -999) - expectedLast) < 0.05)
        // No real hand in this synthetic clip — every sample should honestly
        // report that, not fabricate geometry.
        #expect(output.samples.allSatisfy { $0.thumbTip == nil })
    }
}
