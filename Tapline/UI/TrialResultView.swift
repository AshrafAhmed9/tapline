import AVKit
import Charts
import RevenueCatUI
import SwiftUI
import TapCore

/// The screen the whole app is built around: the shrinking bars are the one
/// image a judge (or a patient) needs to see to understand what Tapline
/// measures that a stopwatch can't.
struct TrialResultView: View {
    let metrics: TapMetricsResult
    let hand: TrialHand
    let videoURL: URL
    let onSave: () -> Void
    let onDiscard: () -> Void

    @Environment(PurchaseManager.self) private var purchases
    @State private var showPaywall = false
    @State private var showReport = false
    @State private var player: AVPlayer?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VideoPlayer(player: player)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .onAppear { player = AVPlayer(url: videoURL) }

                amplitudeChart
                    .padding(.horizontal)

                statGrid
                    .padding(.horizontal)

                reportButton
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("Discard", role: .destructive, action: onDiscard)
                        .buttonStyle(.bordered)
                    Button("Save to history", action: onSave)
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showPaywall) {
            PaywallView(displayCloseButton: true)
        }
        .sheet(isPresented: $showReport) {
            VisitReportView(metrics: metrics, hand: hand)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(plainLanguageSummary)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Text("\(hand.label) · \(metrics.tapCount) taps in \(String(format: "%.0f", metrics.durationSeconds))s")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var plainLanguageSummary: String {
        if metrics.decrementPercent > 15 {
            "Your taps got \(Int(metrics.decrementPercent))% smaller by the end."
        } else if metrics.decrementPercent > 5 {
            "A slight fade — your taps got a little smaller over time."
        } else {
            "Your tapping stayed steady from start to finish."
        }
    }

    private var amplitudeChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap-by-tap width").font(.caption.bold()).foregroundStyle(.secondary)
            Chart {
                ForEach(Array(metrics.amplitudes.enumerated()), id: \.offset) { index, amplitude in
                    BarMark(
                        x: .value("Tap", index + 1),
                        y: .value("Width", amplitude)
                    )
                    .foregroundStyle(barColor(for: index))
                }
            }
            .frame(height: 140)
            .chartXAxis(.hidden)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func barColor(for index: Int) -> Color {
        let fraction = metrics.amplitudes.count > 1 ? Double(index) / Double(metrics.amplitudes.count - 1) : 0
        return Color(hue: 0.55 - 0.55 * fraction, saturation: 0.7, brightness: 0.85)
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Rate", value: String(format: "%.1f taps/s", metrics.tapsPerSecond))
            StatTile(title: "Decrement", value: String(format: "%.0f%%", metrics.decrementPercent))
            StatTile(title: "Hesitations", value: "\(metrics.hesitationCount)")
            StatTile(title: "Rhythm CV", value: String(format: "%.2f", metrics.rhythmCV))
        }
    }

    private var reportButton: some View {
        Button {
            if purchases.isPro {
                showReport = true
            } else {
                showPaywall = true
            }
        } label: {
            HStack {
                Image(systemName: purchases.isPro ? "doc.text" : "lock.fill")
                Text("Prepare visit report")
                Spacer()
                Text(purchases.isPro ? "" : "Plus")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
