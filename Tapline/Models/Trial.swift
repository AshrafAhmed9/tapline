import Foundation
import SwiftData
import TapCore

enum TrialHand: String, Codable, CaseIterable, Identifiable, Equatable {
    case left, right
    var id: String { rawValue }
    var label: String { self == .left ? "Left hand" : "Right hand" }
}

enum DoseState: String, Codable, CaseIterable, Identifiable {
    case on, off, unsure
    var id: String { rawValue }
    var label: String {
        switch self {
        case .on: "ON (medication working)"
        case .off: "OFF (wearing off / before dose)"
        case .unsure: "Not sure"
        }
    }
}

/// One completed, quality-gate-passed trial. Deliberately stores only the
/// numbers TapMetrics produced — never the video, which is discarded after
/// analysis so there's no growing library of camera footage on the phone.
@Model
final class Trial {
    var date: Date
    var hand: TrialHand
    var doseState: DoseState
    var minutesSinceLastDose: Int?

    var tapCount: Int
    var tapsPerSecond: Double
    var meanAmplitude: Double
    var decrementPercent: Double
    var amplitudeSlope: Double
    var hesitationCount: Int
    var rhythmCV: Double

    /// The per-tap amplitudes, for the shrinking-bars chart. Small enough
    /// (≤ ~40 doubles) to store directly rather than a separate model.
    var amplitudes: [Double]

    init(
        date: Date = .now,
        hand: TrialHand,
        doseState: DoseState,
        minutesSinceLastDose: Int?,
        metrics: TapMetricsResult
    ) {
        self.date = date
        self.hand = hand
        self.doseState = doseState
        self.minutesSinceLastDose = minutesSinceLastDose
        self.tapCount = metrics.tapCount
        self.tapsPerSecond = metrics.tapsPerSecond
        self.meanAmplitude = metrics.meanAmplitude
        self.decrementPercent = metrics.decrementPercent
        self.amplitudeSlope = metrics.amplitudeSlope
        self.hesitationCount = metrics.hesitationCount
        self.rhythmCV = metrics.rhythmCV
        self.amplitudes = metrics.amplitudes
    }
}
