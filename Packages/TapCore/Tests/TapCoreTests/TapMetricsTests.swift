import CoreGraphics
import Testing
@testable import TapCore

/// All tests run on synthetic signals — no camera, no device, no Vision
/// runtime needed. This is what lets `swift test` be a real go/no-go check
/// for the tap-counting logic on any machine, including CI.
struct TapMetricsTests {

    // MARK: - Synthetic signal generation

    /// A clean sine wave in [0, amplitude], sampled at `fps`, standing in for
    /// perfect thumb-index tracking. Taps land at the troughs.
    static func sineSignal(
        seconds: Double,
        fps: Double,
        tapRateHz: Double,
        amplitude: (Double) -> Double,
        jitter: Double = 0
    ) -> [SignalPoint] {
        let frameCount = Int(seconds * fps)
        return (0..<frameCount).map { i in
            let t = Double(i) / fps
            let phase = 2 * Double.pi * tapRateHz * t
            // Shift so it starts open (peak) at t=0, matching a real trial.
            let raw = (1 - cos(phase)) / 2
            let noise = jitter == 0 ? 0 : Double.random(in: -jitter...jitter)
            return SignalPoint(timestamp: t, value: raw * amplitude(t) + noise)
        }
    }

    // MARK: - TapDetector

    @Test func detectsExpectedTapCountOnCleanSignal() {
        // 10 seconds at 3 Hz ≈ 30 taps.
        let signal = Self.sineSignal(seconds: 10, fps: 60, tapRateHz: 3, amplitude: { _ in 1.0 })
        let taps = TapDetector.detect(signal: signal, strategy: .adaptive())
        #expect(taps.count >= 27 && taps.count <= 31)
    }

    @Test func adaptiveDetectorTracksDecayingAmplitude() {
        // Amplitude shrinks from 1.0 to 0.15 over the trial — a strong,
        // clinically realistic decrement.
        let signal = Self.sineSignal(
            seconds: 10, fps: 60, tapRateHz: 3,
            amplitude: { t in max(0.15, 1.0 - 0.09 * t) }
        )
        let taps = TapDetector.detect(signal: signal, strategy: .adaptive())
        // Adaptive thresholds should still find taps deep into the decay.
        #expect(taps.count >= 24)
        #expect(taps.last!.time > 8.0)
    }

    @Test func fixedCalibratedDetectorMissesLateSmallTaps() {
        // Same decaying signal. A detector calibrated once on the first 2s
        // (when taps are still large) should miss the shrunken late taps —
        // this is the exact gap Tapline's adaptive detector is built to
        // close, and the number the benchmark reports.
        let signal = Self.sineSignal(
            seconds: 10, fps: 60, tapRateHz: 3,
            amplitude: { t in max(0.15, 1.0 - 0.09 * t) }
        )
        let adaptive = TapDetector.detect(signal: signal, strategy: .adaptive())
        let fixed = TapDetector.detect(signal: signal, strategy: .fixedCalibrated())

        #expect(fixed.count < adaptive.count)
        // Specifically, the fixed detector should go quiet well before the
        // trial ends, while adaptive keeps detecting near the end.
        let fixedLastTapTime = fixed.last?.time ?? 0
        #expect(fixedLastTapTime < 8.0)
    }

    @Test func detectorIsRobustToJitter() {
        let signal = Self.sineSignal(seconds: 10, fps: 60, tapRateHz: 2.5, amplitude: { _ in 1.0 }, jitter: 0.03)
        let taps = TapDetector.detect(signal: signal, strategy: .adaptive())
        // 10s at 2.5Hz ≈ 25 taps; small sensor jitter shouldn't cause
        // double-counting or dropped taps beyond a couple.
        #expect(abs(taps.count - 25) <= 3)
    }

    @Test func doesNotDoubleCountAtNearZeroClosure() {
        // Fingers fully touch (value → 0) at each tap — the exact condition
        // that makes naive threshold-crossing detectors double-count from
        // sensor noise right at contact.
        let signal = Self.sineSignal(seconds: 6, fps: 60, tapRateHz: 2, amplitude: { _ in 1.0 }, jitter: 0.02)
            .map { point -> SignalPoint in
                guard let v = point.value else { return point }
                return SignalPoint(timestamp: point.timestamp, value: max(0, v))
            }
        let taps = TapDetector.detect(signal: signal, strategy: .adaptive())
        // 6s at 2Hz = 12 taps.
        #expect(abs(taps.count - 12) <= 2)
    }

    @Test func handlesGapsWithoutCrashingOrFabricatingTaps() {
        var signal = Self.sineSignal(seconds: 6, fps: 60, tapRateHz: 2, amplitude: { _ in 1.0 })
        // Blank out a 1-second stretch in the middle (hand left frame).
        signal = signal.map { point in
            (2.0...3.0).contains(point.timestamp) ? SignalPoint(timestamp: point.timestamp, value: nil) : point
        }
        let taps = TapDetector.detect(signal: signal, strategy: .adaptive())
        #expect(taps.count > 0)
        #expect(taps.allSatisfy { $0.time.isFinite })
    }

    // MARK: - TapMetrics

    @Test func computesDecrementPercentOnShrinkingTaps() {
        let taps = [
            Tap(index: 0, time: 0.4, openPeakTime: 0.2, amplitude: 1.0),
            Tap(index: 1, time: 0.8, openPeakTime: 0.6, amplitude: 0.95),
            Tap(index: 2, time: 1.2, openPeakTime: 1.0, amplitude: 0.9),
            Tap(index: 3, time: 1.6, openPeakTime: 1.4, amplitude: 0.6),
            Tap(index: 4, time: 2.0, openPeakTime: 1.8, amplitude: 0.5),
            Tap(index: 5, time: 2.4, openPeakTime: 2.2, amplitude: 0.45),
        ]
        let metrics = TapMetricsResult.compute(taps: taps, durationSeconds: 2.5)
        // first3 mean = 0.95, last3 mean ≈ 0.5167 → decrement ≈ 45.6%
        #expect(metrics.decrementPercent > 40 && metrics.decrementPercent < 50)
        #expect(metrics.amplitudeSlope < 0)
        #expect(metrics.tapCount == 6)
    }

    @Test func zeroDecrementOnStableAmplitude() {
        let taps = (0..<8).map { i in
            Tap(index: i, time: Double(i) * 0.3 + 0.15, openPeakTime: Double(i) * 0.3, amplitude: 1.0)
        }
        let metrics = TapMetricsResult.compute(taps: taps, durationSeconds: 2.4)
        #expect(abs(metrics.decrementPercent) < 1)
        #expect(abs(metrics.amplitudeSlope) < 0.01)
    }

    @Test func flagsHesitationsFromLongGaps() {
        // Regular 0.3s taps, except one 1.2s freeze in the middle.
        var times: [Double] = []
        var t = 0.0
        for i in 0..<10 {
            t += (i == 5) ? 1.2 : 0.3
            times.append(t)
        }
        let taps = times.enumerated().map { i, time in
            Tap(index: i, time: time, openPeakTime: time - 0.15, amplitude: 1.0)
        }
        let metrics = TapMetricsResult.compute(taps: taps, durationSeconds: t)
        #expect(metrics.hesitationCount >= 1)
    }

    @Test func emptyTapsProduceZeroedMetricsWithoutCrashing() {
        let metrics = TapMetricsResult.compute(taps: [], durationSeconds: 10)
        #expect(metrics.tapCount == 0)
        #expect(metrics.tapsPerSecond == 0)
        #expect(metrics.decrementPercent == 0)
        #expect(metrics.rhythmCV == 0)
    }

    // MARK: - TapSignalBuilder (hand-scale normalization + gap filling)

    @Test func normalizesByMedianHandScaleNotPerFrameScale() {
        // Hand scale (wrist-to-MCP) varies frame to frame due to rotation,
        // but the underlying tap amplitude is constant. Per-frame
        // normalization would fake a decrement; median normalization
        // should not.
        let samples: [TapSample] = (0..<60).map { i in
            let t = Double(i) / 30.0
            let scaleWobble = 1.0 + 0.15 * sin(Double(i) * 0.3) // rotation noise
            let tapPhase = (1 - cos(2 * .pi * 1.5 * t)) / 2 // 1.5 Hz taps
            let gap = 0.05 + tapPhase * 0.3 // thumb-index distance
            return TapSample(
                timestamp: t,
                thumbTip: CGPoint(x: 0, y: 0),
                indexTip: CGPoint(x: gap * scaleWobble, y: 0),
                wrist: CGPoint(x: -10, y: 0),
                middleMCP: CGPoint(x: -10 + 0.1 * scaleWobble, y: 0),
                confidence: 0.9
            )
        }
        let signal = TapSignalBuilder.build(from: samples)
        let values = signal.compactMap(\.value)
        #expect(!values.isEmpty)
        // With median normalization the signal should still cleanly separate
        // into open/closed phases, i.e. detection still finds multiple taps.
        let taps = TapDetector.detect(signal: signal, strategy: .adaptive())
        #expect(taps.count >= 3)
    }

    @Test func fillsShortGapsButNotLongDropouts() {
        var samples: [TapSample] = (0..<30).map { i in
            TapSample(
                timestamp: Double(i) / 30.0,
                thumbTip: CGPoint(x: 0, y: 0),
                indexTip: CGPoint(x: 0.2, y: 0),
                wrist: CGPoint(x: -10, y: 0),
                middleMCP: CGPoint(x: -9, y: 0),
                confidence: 0.9
            )
        }
        // 2-frame dropout (should be bridged) at index 10-11.
        samples[10] = TapSample(timestamp: samples[10].timestamp, thumbTip: nil, indexTip: nil, wrist: nil, middleMCP: nil, confidence: nil)
        samples[11] = TapSample(timestamp: samples[11].timestamp, thumbTip: nil, indexTip: nil, wrist: nil, middleMCP: nil, confidence: nil)
        // 10-frame dropout (should NOT be bridged) at index 15-24.
        for i in 15..<25 {
            samples[i] = TapSample(timestamp: samples[i].timestamp, thumbTip: nil, indexTip: nil, wrist: nil, middleMCP: nil, confidence: nil)
        }

        let signal = TapSignalBuilder.build(from: samples)
        #expect(signal[10].value != nil, "a 2-frame gap should be bridged")
        #expect(signal[11].value != nil, "a 2-frame gap should be bridged")
        #expect(signal[20].value == nil, "a 10-frame dropout should stay unfilled")
    }

    // MARK: - QualityGate

    @Test func refusesTrialWithTooFewTaps() {
        let samples = fullConfidenceSamples(count: 60)
        let signal = TapSignalBuilder.build(from: samples)
        let verdict = QualityGate.evaluate(samples: samples, signal: signal, taps: [], droppedFrameFraction: 0)
        #expect(verdict != .ok)
    }

    @Test func refusesTrialWithMostlyMissingHand() {
        var samples = fullConfidenceSamples(count: 100)
        for i in 0..<50 {
            samples[i] = TapSample(timestamp: samples[i].timestamp, thumbTip: nil, indexTip: nil, wrist: nil, middleMCP: nil, confidence: nil)
        }
        let signal = TapSignalBuilder.build(from: samples)
        let verdict = QualityGate.evaluate(samples: samples, signal: signal, taps: [], droppedFrameFraction: 0)
        guard case .refused = verdict else {
            Issue.record("expected refusal when half the hand data is missing")
            return
        }
    }

    @Test func acceptsGoodTrial() {
        let samples: [TapSample] = (0..<300).map { i in
            let t = Double(i) / 60.0
            let tapPhase = (1 - cos(2 * .pi * 3 * t)) / 2
            let gap = 0.05 + tapPhase * 0.3
            return TapSample(
                timestamp: t,
                thumbTip: CGPoint(x: 0, y: 0),
                indexTip: CGPoint(x: gap, y: 0),
                wrist: CGPoint(x: -10, y: 0),
                middleMCP: CGPoint(x: -9, y: 0),
                confidence: 0.9
            )
        }
        let signal = TapSignalBuilder.build(from: samples)
        let taps = TapDetector.detect(signal: signal, strategy: .adaptive())
        let verdict = QualityGate.evaluate(samples: samples, signal: signal, taps: taps, droppedFrameFraction: 0.01)
        #expect(verdict == .ok)
    }

    private func fullConfidenceSamples(count: Int) -> [TapSample] {
        (0..<count).map { i in
            TapSample(
                timestamp: Double(i) / 30.0,
                thumbTip: CGPoint(x: 0, y: 0),
                indexTip: CGPoint(x: 0.2, y: 0),
                wrist: CGPoint(x: -10, y: 0),
                middleMCP: CGPoint(x: -9, y: 0),
                confidence: 0.9
            )
        }
    }
}
