import SwiftUI

/// Onboarding gate, then the two-tab app: run a test, or look at history.
struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            TabView {
                TrialFlowView()
                    .tabItem { Label("Test", systemImage: "hand.tap") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "chart.line.uptrend.xyaxis") }
            }
        } else {
            OnboardingView {
                withAnimation { hasSeenOnboarding = true }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Trial.self, inMemory: true)
        .environment(PurchaseManager())
}
