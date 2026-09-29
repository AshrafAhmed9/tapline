import SwiftUI

/// First screen of every trial: which hand, and how the medication is
/// sitting right now. Asked before the camera comes up so the tag is never
/// an afterthought bolted onto the result.
struct HandPickerView: View {
    let onPick: (TrialHand, DoseState, Int?) -> Void

    @State private var hand: TrialHand = .right
    @State private var doseState: DoseState = .unsure
    @State private var minutesSinceDose: Double = 60
    @State private var trackDose = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("New test").font(.largeTitle.bold())
                    Text("Prop your phone up. You'll have both hands free.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    Text("WHICH HAND").font(.caption.bold()).foregroundStyle(.secondary)
                    Picker("Hand", selection: $hand) {
                        ForEach(TrialHand.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Tag medication timing", isOn: $trackDose.animation())
                        .font(.subheadline.bold())
                    if trackDose {
                        Picker("State", selection: $doseState) {
                            ForEach(DoseState.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()

                        VStack(alignment: .leading) {
                            Text("Minutes since last dose: \(Int(minutesSinceDose))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $minutesSinceDose, in: 0...360, step: 5)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Sit side-on to the camera so your whole hand stays in frame.", systemImage: "person.and.background.dotted")
                    Label("Tap your thumb and index finger as wide and as fast as you can.", systemImage: "hand.tap")
                    Label("Keep going for the full 10 seconds, even if you slow down.", systemImage: "timer")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)

                Button {
                    onPick(hand, trackDose ? doseState : .unsure, trackDose ? Int(minutesSinceDose) : nil)
                } label: {
                    Text("Start 10-second test")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    HandPickerView(onPick: { _, _, _ in })
}
