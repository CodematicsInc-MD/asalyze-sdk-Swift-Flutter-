import Foundation

/// Thin HTTP client for the ingest plane. Authenticates with the per-app api key. All calls are
/// best-effort fire-and-forget from the caller's perspective (failures are logged, not thrown).
actor APIClient {
    private let config: Config
    private let session: URLSession

    init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Ingest event variants → POST /v1/event.
    ///
    /// Ad revenue only. Purchases are observed from StoreKit, never reported through here.
    enum Event {
        // region travels WITH the impression, not with the install: eCPM is set by where the ad was
        // actually served, and a user who installed in one country and is now in another would otherwise
        // have every impression priced against a stale geography.
        case ad(installId: String, value: Double, currency: String, format: AdFormat, region: String?)
    }

    func registerInstall(installId: String, attributionToken: String?, environment: String, isReinstall: Bool = false,
                         appVersion: String? = nil, appBuild: String? = nil, installedAt: Date? = nil,
                         deviceRegion: String? = nil, osVersion: String? = nil, legacyReceipt: String? = nil,
                         appTransactionJws: String? = nil, sdkVersion: String? = nil,
                         tokenError: String? = nil) async {
        var body: [String: Any] = ["installId": installId, "environment": environment]
        if let attributionToken { body["attributionToken"] = attributionToken }
        if isReinstall { body["isReinstall"] = true }
        if let appVersion { body["appVersion"] = appVersion }
        if let appBuild { body["appBuild"] = appBuild }
        if let installedAt { body["installedAt"] = ISO8601DateFormatter().string(from: installedAt) }
        if let deviceRegion { body["deviceRegion"] = deviceRegion }
        if let osVersion { body["osVersion"] = osVersion }
        if let legacyReceipt { body["legacyReceipt"] = legacyReceipt }
        if let appTransactionJws { body["appTransactionJws"] = appTransactionJws }
        if let sdkVersion { body["sdkVersion"] = sdkVersion }
        // Only when there is no token — a reason beside a working token would read as a failure.
        if attributionToken == nil, let tokenError { body["tokenError"] = tokenError }
        await post("/v1/install", body)
    }

    func recordEvent(_ event: Event) async {
        switch event {
        case let .ad(installId, value, currency, format, region):
            var body: [String: Any] = ["installId": installId, "type": "ad", "value": value,
                                       "currency": currency, "adFormat": format.rawValue]
            if let region { body["region"] = region }
            await post("/v1/event", body)
        }
    }

    func recordCustomEvent(installId: String, name: String, value: Double?) async {
        var body: [String: Any] = ["installId": installId, "name": name]
        if let value { body["value"] = value }
        await post("/v1/custom-event", body)
    }

    /// Returns whether the report landed (2xx). The caller only marks the transaction as "sent" on
    /// success, so a failed POST is retried from `Transaction.all` on the next launch (StoreKit keeps
    /// every transaction, so it's a durable retry queue; the backend dedups on `transactionId`).
    @discardableResult
    func recordSubscription(_ tx: ObservedTransaction, installId: String) async -> Bool {
        var body: [String: Any] = ["installId": installId, "originalTxnId": tx.originalTxnId,
                                    "transactionId": tx.transactionId,
                                    "productId": tx.productId, "type": tx.type.rawValue,
                                    "environment": tx.environment, "purchaseType": tx.purchaseType]
        if let price = tx.priceUsd { body["price"] = price }
        if let currency = tx.currency { body["currency"] = currency }
        if let occurredAt = tx.occurredAt {
            body["occurredAt"] = ISO8601DateFormatter().string(from: occurredAt)
        }
        return await post("/v1/subscription", body)
    }

    /// "This device still has the app" → POST /v1/ping.
    ///
    /// Deliberately the smallest possible call: an install id and nothing else. It exists so that
    /// last-seen means last USE rather than last cold launch — registerInstall only runs at startup, so
    /// a user who never force-quits could open the app daily for a month and still look lapsed.
    ///
    /// It does NOT detect uninstalls, and must never be presented as if it did. Silence means the app
    /// was not opened; whether it is still installed is a different question this cannot answer.
    func ping(installId: String) async {
        _ = await post("/v1/ping", ["installId": installId])
    }

    /// Best-effort POST. Returns `true` only on a 2xx response so callers can decide whether to persist
    /// the item for retry. Network errors and non-2xx responses return `false` (and are logged).
    @discardableResult
    private func post(_ path: String, _ body: [String: Any]) async -> Bool {
        guard let url = URL(string: path, relativeTo: config.endpoint) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await session.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(code) { return true }
            NSLog("[Asalyze] POST \(path) → HTTP \(code)")
            return false
        } catch {
            NSLog("[Asalyze] POST \(path) failed: \(error.localizedDescription)")
            return false
        }
    }
}
