import Foundation
#if canImport(StoreKit)
import StoreKit
#endif

/// Public facade for the ASA ROAS Tracker SDK.
///
/// One call — `configure` — wires up first-party AdServices attribution and StoreKit 2 purchase
/// observation. Purchases, renewals and refunds need no code: StoreKit is the source of the price,
/// currency, offer type and transaction id. Ad revenue is the one thing Apple cannot see, so
/// `trackAdRevenue` reports it.
///
/// ```swift
/// Asalyze.configure(apiKey: "sk_…", appId: "com.your.app")
/// ```
public enum Asalyze {
    private static var runtime: Runtime?

    /// Configure the SDK. Call once, as early as possible (App init / didFinishLaunching).
    /// - Parameters:
    ///   - apiKey: the per-app key from the dashboard (Test Devices / My Apps).
    ///   - appId: your bundle identifier.
    ///   - endpoint: backend base URL. Defaults to production.
    public static func configure(apiKey: String, appId: String, endpoint: URL = Config.defaultEndpoint) {
        let config = Config(apiKey: apiKey, appId: appId, endpoint: endpoint)
        let runtime = Runtime(config: config)
        self.runtime = runtime
        runtime.start()
    }

    /// Expose the stable first-party install id (no IDFA) — useful to reconcile with your own analytics.
    public static var installId: String? { runtime?.installId }



    /// Optionally tag events with your own user id (see docs — enables cross-device reconciliation).
    public static func setUserId(_ userId: String?) {
        runtime?.userId = userId
    }


    /// Report impression-level ad revenue (e.g. from AdMob's `paidEventHandler`).
    public static func trackAdRevenue(valueUsd: Double, format: AdFormat, currency: String = "USD") {
        runtime?.trackAdRevenue(value: valueUsd, currency: currency, format: format)
    }

    /// Report a named custom event for Goals (e.g. "completed_onboarding", "reached_level_5").
    public static func trackEvent(_ name: String, valueUsd: Double? = nil) {
        runtime?.trackCustomEvent(name: name, value: valueUsd)
    }

}
