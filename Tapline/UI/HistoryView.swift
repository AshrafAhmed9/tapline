import Charts
import RevenueCatUI
import SwiftData
import SwiftUI

/// Free: the last 14 days. Plus: the full trend. This is the one place in
/// the app where the free tier's limit is visible rather than just implied —
/// the row that's cut off says exactly what unlocking buys.
struct HistoryView: View {
    @Query(sort: \Trial.date, order: .reverse) private var allTrials: [Trial]
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.modelContext) private var modelContext
    @State private var showPaywall = false

    private static let freeHistoryWindow: TimeInterval = 14 * 24 * 3600

    private var visibleTrials: [Trial] {
        purchases.isPro ? allTrials : allTrials.filter { Date.now.timeIntervalSince($0.date) <= Self.freeHistoryWindow }
    }

    private var hiddenCount: Int { allTrials.count - visibleTrials.count }

    var body: some View {
        NavigationStack {
            Group {
                if allTrials.isEmpty {
                    ContentUnavailableView(
                        "No tests yet",
                        systemImage: "hand.tap",
                        description: Text("Run your first tapping test from the Test tab.")
                    )
                } else {
                    List {
                        if visibleTrials.count >= 2 {
                            Section("Decrement trend") {
                                trendChart
                            }
                        }
                        Section("Trials") {
                            ForEach(visibleTrials) { trial in
                                TrialRow(trial: trial)
                            }
                            .onDelete(perform: delete)
                        }
                        if hiddenCount > 0 {
                            Section {
                                Button {
                                    showPaywall = true
                                } label: {
                                    Label("\(hiddenCount) older \(hiddenCount == 1 ? "trial is" : "trials are") locked — unlock full history", systemImage: "lock.fill")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(isPresented: $showPaywall) {
                PaywallView(displayCloseButton: true)
            }
        }
    }

    private var trendChart: some View {
        Chart(visibleTrials.reversed()) { trial in
            LineMark(
                x: .value("Date", trial.date),
                y: .value("Decrement %", trial.decrementPercent)
            )
            .symbol(.circle)
        }
        .frame(height: 140)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visibleTrials[index])
        }
    }
}

private struct TrialRow: View {
    let trial: Trial

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(trial.hand.label).font(.subheadline.bold())
                Text(trial.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if trial.doseState != .unsure {
                    Text(trial.doseState.label)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(trial.doseState == .on ? .green.opacity(0.2) : .orange.opacity(0.2), in: Capsule())
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(trial.tapCount) taps").font(.subheadline.bold())
                Text(String(format: "%.0f%% decrement", trial.decrementPercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: Trial.self, inMemory: true)
        .environment(PurchaseManager())
}
