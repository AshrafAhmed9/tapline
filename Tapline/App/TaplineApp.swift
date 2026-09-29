import SwiftData
import SwiftUI

@main
struct TaplineApp: App {
    @State private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(purchases)
                .task { purchases.configure() }
        }
        .modelContainer(for: Trial.self)
    }
}
