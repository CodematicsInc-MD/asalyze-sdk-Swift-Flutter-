import XCTest
@testable import Asalyze

final class AsalyzeTests: XCTestCase {
    func testConfigDefaults() {
        let c = Config(apiKey: "sk_test", appId: "com.x.app")
        XCTAssertEqual(c.apiKey, "sk_test")
        XCTAssertEqual(c.endpoint, Config.defaultEndpoint)
    }

    func testAdFormatRawValues() {
        XCTAssertEqual(AdFormat.rewardedInterstitial.rawValue, "rewarded_interstitial")
        XCTAssertEqual(AdFormat.appOpen.rawValue, "app_open")
    }

    func testAdMobMicrosConversion() {
        // 9_990_000 micros = 9.99 in the ad currency.
        XCTAssertEqual(Double(9_990_000) / 1_000_000.0, 9.99, accuracy: 1e-9)
    }
}
