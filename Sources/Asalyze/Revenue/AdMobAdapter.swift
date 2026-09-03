import Foundation

/// Helper for routing AdMob paid events into ROAS without adding a hard dependency on GoogleMobileAds.
/// Wire it into each ad's `paidEventHandler` — pass `value.value` straight through:
///
/// ```swift
/// appOpenAd.paidEventHandler = { value in
///     AsalyzeAdMob.report(value.value, currencyCode: value.currencyCode,
///                         precision: value.precision.rawValue, format: .appOpen)
/// }
/// ```
public enum AsalyzeAdMob {
    /// PREFERRED. Pass AdMob's `GADAdValue.value` (an `NSDecimalNumber`, in the ad currency's units)
    /// directly — no micro-unit conversion needed.
    public static func report(_ value: NSDecimalNumber, currencyCode: String, precision: Int = 0, format: AdFormat) {
        Asalyze.trackAdRevenue(valueUsd: value.doubleValue, format: format, currency: currencyCode)
    }

    /// For callers that already hold the value in micro-units (millionths of the ad currency).
    public static func report(micros: Int64, currencyCode: String, precision: Int = 0, format: AdFormat) {
        Asalyze.trackAdRevenue(valueUsd: Double(micros) / 1_000_000.0, format: format, currency: currencyCode)
    }
}
