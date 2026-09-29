import Foundation
import TapCore

/// Runs the exact same TapCore code the iPhone app uses over a folder of
/// videos, and reports two numbers:
///
/// 1. **Late-trial detection gap** (no ground truth needed): on real PD
///    footage, how many more taps the adaptive detector finds in the last
///    third of each trial than a detector calibrated once at the start —
///    the fixed baseline's blind spot is exactly the decremented late taps
///    that matter clinically. (The exact-count version of this claim, with
///    synthetic ground truth, lives in `TapCoreTests` — this is its
///    real-footage companion.)
/// 2. **Clinical association** (needs the dataset's label CSV): Spearman ρ
///    between a fixed, unlearned kinematic composite and the clinician
///    score, plus AUC separating PD from control — reported for a
///    rate-only composite and for rate+amplitude+decrement, so the ablation
///    shows what the camera adds over what a tap-counting app already gets.
///
/// Usage:
///   tapbench <videosDir> [--labels path.csv] [--filename-col NAME]
///            [--score-col NAME] [--group-col NAME] [--pd-value STRING]
///            [--out dir] [--seed N] [--dev-fraction 0.2]

struct VideoResult {
    let filename: String
    let verdict: QualityVerdict
    let metrics: TapMetricsResult?
    let adaptiveLastThirdCount: Int
    let fixedLastThirdCount: Int
    var clinicalScore: Double?
    var isPD: Bool?
}

@main
struct TapBench {
    static func main() async {
        let args = CommandLineArgs(CommandLine.arguments)
        guard let videosDir = args.positional.first else {
            print("Usage: tapbench <videosDir> [--labels path.csv] [--out dir]")
            exit(1)
        }
        let outDir = args.value("--out") ?? "bench"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let videoFiles = findVideos(in: videosDir)
        print("Found \(videoFiles.count) video files under \(videosDir)")
        guard !videoFiles.isEmpty else { exit(1) }

        var labelsByStem: [String: [String: String]] = [:]
        var filenameCol: String?, scoreCol: String?, groupCol: String?
        if let labelsPath = args.value("--labels") {
            do {
                let table = try CSV.parse(url: URL(fileURLWithPath: labelsPath))
                print("Label columns: \(table.header)")
                filenameCol = args.value("--filename-col") ?? guessFilenameColumn(table, videoStems: Set(videoFiles.map { stem($0.lastPathComponent) }))
                scoreCol = args.value("--score-col") ?? guessColumn(table, containing: ["updrs", "score", "rating", "severity"])
                groupCol = args.value("--group-col") ?? guessColumn(table, containing: ["group", "diagnosis", "label", "class", "condition"])
                print("Using filename column: \(filenameCol ?? "none found"), score column: \(scoreCol ?? "none found"), group column: \(groupCol ?? "none found")")
                if let filenameCol {
                    for row in table.rows {
                        guard let name = row[filenameCol] else { continue }
                        labelsByStem[stem(name)] = row
                    }
                }
            } catch {
                print("Could not read labels CSV: \(error)")
            }
        }

        let pdValue = (args.value("--pd-value") ?? "pd").lowercased()

        var results: [VideoResult] = []
        for (index, videoURL) in videoFiles.enumerated() {
            print("[\(index + 1)/\(videoFiles.count)] \(videoURL.lastPathComponent)")
            do {
                let output = try await TrialAnalyzer.analyze(videoURL: videoURL)
                let signal = TapSignalBuilder.build(from: output.samples)
                let adaptiveTaps = TapDetector.detect(signal: signal, strategy: .adaptive())
                let fixedTaps = TapDetector.detect(signal: signal, strategy: .fixedCalibrated())
                let verdict = QualityGate.evaluate(samples: output.samples, signal: signal, taps: adaptiveTaps, droppedFrameFraction: 0)
                let duration = output.samples.last?.timestamp ?? 0
                let metrics = verdict == .ok ? TapMetricsResult.compute(taps: adaptiveTaps, durationSeconds: duration) : nil

                let cutoff = duration * (2.0 / 3.0)
                let adaptiveLate = adaptiveTaps.filter { $0.time >= cutoff }.count
                let fixedLate = fixedTaps.filter { $0.time >= cutoff }.count

                var result = VideoResult(
                    filename: videoURL.lastPathComponent,
                    verdict: verdict,
                    metrics: metrics,
                    adaptiveLastThirdCount: adaptiveLate,
                    fixedLastThirdCount: fixedLate
                )

                if let row = labelsByStem[stem(videoURL.lastPathComponent)] {
                    if let scoreCol, let raw = row[scoreCol], let value = Double(raw) {
                        result.clinicalScore = value
                    }
                    if let groupCol, let raw = row[groupCol] {
                        result.isPD = raw.lowercased().contains(pdValue)
                    }
                }
                results.append(result)
            } catch {
                print("  failed: \(error)")
                results.append(VideoResult(filename: videoURL.lastPathComponent, verdict: .refused(reason: "\(error)"), metrics: nil, adaptiveLastThirdCount: 0, fixedLastThirdCount: 0))
            }
        }

        writeResultsCSV(results, to: "\(outDir)/results.csv")
        writeSummary(results, to: "\(outDir)/summary.md", seed: Int(args.value("--seed") ?? "42") ?? 42, devFraction: Double(args.value("--dev-fraction") ?? "0.2") ?? 0.2)
        print("Wrote \(outDir)/results.csv and \(outDir)/summary.md")
    }

    static func findVideos(in dir: String) -> [URL] {
        let exts: Set<String> = ["mp4", "mov", "avi", "m4v"]
        guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil) else { return [] }
        var urls: [URL] = []
        for case let url as URL in enumerator where exts.contains(url.pathExtension.lowercased()) {
            urls.append(url)
        }
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func stem(_ filename: String) -> String {
        (filename as NSString).deletingPathExtension
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    static func guessFilenameColumn(_ table: CSV.Table, videoStems: Set<String>) -> String? {
        var bestColumn: String?
        var bestMatches = 0
        for column in table.header {
            let matches = table.rows.filter { row in
                guard let value = row[column] else { return false }
                return videoStems.contains(stem(value))
            }.count
            if matches > bestMatches {
                bestMatches = matches
                bestColumn = column
            }
        }
        return bestMatches > 0 ? bestColumn : nil
    }

    static func guessColumn(_ table: CSV.Table, containing keywords: [String]) -> String? {
        table.header.first { header in
            let lower = header.lowercased()
            return keywords.contains { lower.contains($0) }
        }
    }

    static func writeResultsCSV(_ results: [VideoResult], to path: String) {
        var lines = ["filename,verdict,tap_count,taps_per_sec,mean_amplitude,decrement_pct,adaptive_late_taps,fixed_late_taps,clinical_score,is_pd"]
        for r in results {
            let verdictStr: String
            switch r.verdict {
            case .ok: verdictStr = "ok"
            case .refused(let reason): verdictStr = "refused: \(reason.replacingOccurrences(of: ",", with: ";"))"
            }
            let m = r.metrics
            lines.append([
                r.filename,
                verdictStr,
                m.map { "\($0.tapCount)" } ?? "",
                m.map { String(format: "%.2f", $0.tapsPerSecond) } ?? "",
                m.map { String(format: "%.4f", $0.meanAmplitude) } ?? "",
                m.map { String(format: "%.1f", $0.decrementPercent) } ?? "",
                "\(r.adaptiveLastThirdCount)",
                "\(r.fixedLastThirdCount)",
                r.clinicalScore.map { "\($0)" } ?? "",
                r.isPD.map { $0 ? "1" : "0" } ?? "",
            ].joined(separator: ","))
        }
        try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func writeSummary(_ results: [VideoResult], to path: String, seed: Int, devFraction: Double) {
        var lines = ["# Tapline benchmark — HUBU-FIS", "", "Generated \(Date.now.formatted()).", ""]

        let total = results.count
        let refused = results.filter { if case .refused = $0.verdict { return true }; return false }.count
        lines.append("- Videos processed: \(total)")
        lines.append("- Refused by the quality gate: \(refused) (\(total > 0 ? Int(Double(refused) / Double(total) * 100) : 0)%)")

        // --- Claim 1: late-trial detection gap (no labels needed) ---
        let scored = results.filter { $0.verdict == .ok }
        if !scored.isEmpty {
            let avgAdaptiveLate = Double(scored.map(\.adaptiveLastThirdCount).reduce(0, +)) / Double(scored.count)
            let avgFixedLate = Double(scored.map(\.fixedLastThirdCount).reduce(0, +)) / Double(scored.count)
            lines.append("")
            lines.append("## Claim 1 — late-trial taps caught, adaptive vs fixed-calibrated")
            lines.append("On real footage, in the last third of each trial (where amplitude decrement is clinically the point):")
            lines.append("- Adaptive detector: **\(String(format: "%.2f", avgAdaptiveLate))** taps/trial on average")
            lines.append("- Fixed-calibrated detector: **\(String(format: "%.2f", avgFixedLate))** taps/trial on average")
            lines.append("")
            lines.append("(Exact-count validation of this mechanism against synthetic ground truth is in `Packages/TapCore/Tests`.)")
        }

        // --- Claim 2: clinical association (needs labels) ---
        let labeled = scored.filter { $0.clinicalScore != nil || $0.isPD != nil }
        if labeled.count >= 6 {
            var rng = SeededGenerator(seed: seed)
            let shuffled = labeled.shuffled(using: &rng)
            let devCount = max(1, Int(Double(shuffled.count) * devFraction))
            let devSet = Array(shuffled.prefix(devCount))
            let heldOut = Array(shuffled.suffix(from: devCount))
            lines.append("")
            lines.append("## Claim 2 — clinical association (pre-declared protocol)")
            lines.append("Dev split: \(devSet.count) videos (seed \(seed)) used only to fix composite weights. Reported below: the held-out \(heldOut.count).")

            reportAssociation(heldOut, into: &lines)
        } else {
            lines.append("")
            lines.append("## Claim 2 — clinical association")
            lines.append("Not enough labeled videos matched (\(labeled.count)). Check --labels/--filename-col/--score-col/--group-col.")
        }

        try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func reportAssociation(_ items: [VideoResult], into lines: inout [String]) {
        let withScore = items.compactMap { r -> (Double, Double, Double)? in
            guard let m = r.metrics, let score = r.clinicalScore else { return nil }
            return (m.tapsPerSecond, m.meanAmplitude * (1 - m.decrementPercent / 100), score)
        }
        if withScore.count >= 4 {
            let rateOnly = withScore.map { -$0.0 } // slower tapping = worse
            let combined = zip(Statistics.zScores(withScore.map { -$0.0 }), Statistics.zScores(withScore.map { -$0.1 }))
                .map { $0 + $1 }
            let scores = withScore.map(\.2)
            if let rhoRate = Statistics.spearman(rateOnly, scores) {
                lines.append("- Rate-only vs clinician score: Spearman ρ = \(String(format: "%.2f", rhoRate))")
            }
            if let rhoCombined = Statistics.spearman(combined, scores) {
                lines.append("- Rate + amplitude + decrement vs clinician score: Spearman ρ = \(String(format: "%.2f", rhoCombined))")
            }
        } else {
            lines.append("- Not enough videos with a numeric clinical score for correlation (\(withScore.count)).")
        }

        let withGroup = items.compactMap { r -> (Double, Double, Bool)? in
            guard let m = r.metrics, let isPD = r.isPD else { return nil }
            return (m.tapsPerSecond, m.meanAmplitude * (1 - m.decrementPercent / 100), isPD)
        }
        if withGroup.count >= 4, Set(withGroup.map(\.2)).count == 2 {
            let rateOnly = withGroup.map { -$0.0 }
            let combined = zip(Statistics.zScores(withGroup.map { -$0.0 }), Statistics.zScores(withGroup.map { -$0.1 }))
                .map { $0 + $1 }
            let labels = withGroup.map(\.2)
            if let aucRate = Statistics.auc(scores: rateOnly, isPositive: labels) {
                lines.append("- Rate-only AUC (PD vs control): \(String(format: "%.2f", aucRate))")
            }
            if let aucCombined = Statistics.auc(scores: combined, isPositive: labels) {
                lines.append("- Rate + amplitude + decrement AUC (PD vs control): \(String(format: "%.2f", aucCombined))")
            }
        } else {
            lines.append("- Not enough videos with both PD and control labels for AUC (\(withGroup.count)).")
        }
    }
}

struct CommandLineArgs {
    let positional: [String]
    private let flags: [String: String]

    init(_ arguments: [String]) {
        var positional: [String] = []
        var flags: [String: String] = [:]
        var i = 1
        while i < arguments.count {
            let arg = arguments[i]
            if arg.hasPrefix("--"), i + 1 < arguments.count {
                flags[arg] = arguments[i + 1]
                i += 2
            } else {
                positional.append(arg)
                i += 1
            }
        }
        self.positional = positional
        self.flags = flags
    }

    func value(_ flag: String) -> String? { flags[flag] }
}

/// Deterministic shuffling so the dev/held-out split is reproducible given
/// the same `--seed`.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
