import SwiftUI
import TapCore
import UIKit
import UniformTypeIdentifiers

/// `UIImage` isn't `Transferable` itself; wrap the PNG bytes so `ShareLink`
/// can hand Messages/Mail/Files an actual file instead of an opaque object.
private struct SharableReportImage: Transferable {
    let uiImage: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { report in
            report.uiImage.pngData() ?? Data()
        }
    }
}

/// The Plus-gated deliverable: a single page summarizing one trial, made to
/// be screenshotted or shared before a neurologist visit. Rendered with
/// `ImageRenderer` rather than a PDF library — one screen's worth of content
/// doesn't need one, and `ShareLink` on the resulting image already lets
/// Messages, Mail and Files all save it (Files will happily save a PNG as a
/// PDF-adjacent attachment; for a hackathon deadline, "share this image" is
/// the honest scope, not "generate a spec-compliant PDF").
struct VisitReportView: View {
    let metrics: TapMetricsResult
    let hand: TrialHand

    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                reportContent
                    .padding(24)
                    .background(Color.white)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Visit Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let renderedImage {
                        ShareLink(
                            item: SharableReportImage(uiImage: renderedImage),
                            preview: SharePreview("Tapline visit report", image: Image(uiImage: renderedImage))
                        )
                    }
                }
            }
            .task { render() }
        }
    }

    private var reportContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tapline — Finger-Tapping Report")
                .font(.title2.bold())
            Text(Date.now.formatted(date: .long, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            Group {
                reportRow("Hand tested", hand.label)
                reportRow("Taps", "\(metrics.tapCount)")
                reportRow("Rate", String(format: "%.1f taps/sec", metrics.tapsPerSecond))
                reportRow("Amplitude decrement", String(format: "%.0f%%", metrics.decrementPercent))
                reportRow("Hesitations", "\(metrics.hesitationCount)")
                reportRow("Rhythm variability (CV)", String(format: "%.2f", metrics.rhythmCV))
            }

            Divider()

            Text("Not a diagnosis. These are raw kinematic measurements of one 10-second self-administered trial, meant as a log to discuss with a clinician — not a clinical score.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.black)
    }

    private func reportRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold()
        }
        .font(.subheadline)
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: reportContent.padding(24).frame(width: 350).background(Color.white))
        renderer.scale = UIScreen.main.scale
        renderedImage = renderer.uiImage
    }
}
