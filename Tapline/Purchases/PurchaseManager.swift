import Observation
import RevenueCat

/// Thin wrapper around the RevenueCat SDK. Everything that gates a feature
/// checks `isPro` here — never a local flag — so there's exactly one source
/// of truth and restoring a purchase or renewing a subscription updates
/// every gated screen automatically.
@MainActor
@Observable
final class PurchaseManager {
    static let entitlementID = "plus"

    private(set) var isPro = false
    private(set) var isConfigured = false

    private var listenTask: Task<Void, Never>?

    /// Reads the key from Info.plist (populated at build time from
    /// `Config/Secrets.xcconfig`, which is gitignored — see
    /// `Config/Secrets.template.xcconfig`). If it's missing or still the
    /// placeholder, purchases stay disabled rather than crashing, so the
    /// rest of the app is still usable for anyone building from source
    /// without setting up RevenueCat first.
    func configure() {
        guard !isConfigured else { return }
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              !apiKey.isEmpty, !apiKey.contains("REPLACE_ME") else {
            return
        }

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true

        listenTask = Task { [weak self] in
            guard let self else { return }
            for await info in Purchases.shared.customerInfoStream {
                self.apply(info)
            }
        }
    }

    func refresh() async {
        guard isConfigured else { return }
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }
    }

    private func apply(_ info: CustomerInfo) {
        isPro = info.entitlements[Self.entitlementID]?.isActive == true
    }
}
