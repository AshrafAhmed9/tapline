import SwiftUI

/// Shown once, before the first trial. Says the three things that matter
/// most for a Parkinson's-facing camera app: what it measures, that nothing
/// leaves the phone, and that it is not a diagnosis.
struct OnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "hand.tap.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Tapline")
                    .font(.largeTitle.bold())
                Text("Measures the finger-tapping test neurologists use to track Parkinson's — on your iPhone, in 10 seconds.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 18) {
                infoRow(icon: "lock.shield", title: "On-device, always", body: "Video is analyzed on your iPhone and deleted right after. Nothing is uploaded.")
                infoRow(icon: "cross.case", title: "Not a medical device", body: "Tapline doesn't diagnose anything. Bring your results to your neurologist — it's a log, not a verdict.")
                infoRow(icon: "chart.line.downtrend.xyaxis", title: "Built to show its work", body: "Every measurement is checked against real, clinician-scored footage. See the numbers in the README.")
            }
            .padding(.horizontal, 28)

            Spacer()

            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
        }
    }

    private func infoRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView(onContinue: {})
}
