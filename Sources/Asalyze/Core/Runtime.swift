import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Internal orchestrator wired up by `Asalyze.configure`. Owns the install identity, the API client,
/// the attribution capture, and the StoreKit observer. Kept `internal` so the public surface stays tiny.
/// The SDK's own version, reported with every install.
///
/// The SDK's own version, sent with every install. Reading it directly beats inferring it from which
/// fields a payload happens to carry: that only works while every release adds one, and cannot tell
/// two releases apart once both send the same set.
let asalyzeSDKVersion = "3.1.3"

final class Runtime {
    let config: Config
    let installId: String
    let isReinstall: Bool
    var userId: String?

    private let api: APIClient
    private let storeKit: StoreKitObserver

    init(config: Config) {
        self.config = config
        let identity = Storage.loadIdentity()
        self.installId = identity.installId
        self.isReinstall = identity.isReinstall
        self.api = APIClient(config: config)
        self.storeKit = StoreKitObserver()
    }

    #if canImport(UIKit)
    private var foregroundObserver: NSObjectProtocol?
    #endif

    deinit {
        #if canImport(UIKit)
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
        #endif
    }

    func start() {
        // 1. Register the install with its AdServices attribution token (resolved server-side) and its
        //    environment (authoritative via StoreKit AppTransaction) — so TestFlight / debug installs land
        //    in Test Devices, not production reports. Also hand the resolved env to the observer so its
        //    events agree with the install (belt-and-suspenders with per-transaction .environment).
        Task {
            let ctx = await SDKEnvironment.appContext()
            self.storeKit.environment = ctx.environment.rawValue
            let attribution = AttributionManager.attributionToken()
            await api.registerInstall(installId: installId, attributionToken: attribution.token, environment: ctx.environment.rawValue,
                                      isReinstall: isReinstall, appVersion: ctx.version, appBuild: ctx.build, installedAt: ctx.installedAt,
                                      deviceRegion: ctx.region, osVersion: ctx.osVersion, legacyReceipt: ctx.legacyReceipt,
                                      appTransactionJws: ctx.appTransactionJws, sdkVersion: asalyzeSDKVersion,
                                      tokenError: attribution.error)
        }
        // 2. Observe StoreKit 2 transactions for the app's lifetime. Mark a transaction as sent only
        //    after the report lands — so a failed POST is retried from `Transaction.all` next launch
        //    (StoreKit is the durable queue; backend dedups on transactionId). This is what stops a
        //    transient network failure from permanently orphaning a purchase.
        storeKit.onTransaction = { [weak self] tx in
            guard let self else { return }
            Task {
                if await self.api.recordSubscription(tx, installId: self.installId) {
                    Storage.markTransactionSent(tx.transactionId)
                }
            }
        }
        storeKit.start()
        startHeartbeat()
    }

    /// How long a device may stay quiet before the next foreground counts as a fresh sighting. A day is
    /// the resolution every report that reads last-seen actually uses, and anything tighter would post
    /// on every app switch for no gain in what we can say.
    private static let heartbeatInterval: TimeInterval = 24 * 60 * 60

    /// Tell the backend the app is still being used, at most once a day.
    ///
    /// registerInstall fires only at startup, so on iOS — where an app can stay resident for weeks — a
    /// daily user who never force-quits was last SEEN whenever they last cold-launched. Reports that
    /// ask "has this cohort gone quiet?" were reading that as churn.
    ///
    /// This is not uninstall tracking. No code runs after an app is deleted, so the SDK cannot report
    /// its own removal; the absence of a ping means "not opened", which is a weaker claim and the only
    /// honest one available here.
    private func startHeartbeat() {
        #if canImport(UIKit)
        // Fire once for THIS foreground too: the app has just become active, which is exactly the
        // event being recorded, and waiting for the next one would miss single-session users entirely.
        beat()
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.beat()
            // A purchase made in this session never reaches Transaction.updates, and the payment sheet
            // restores the app as it closes — so this is where an unreported sale gets caught.
            self?.storeKit.rescan()
        }
        #endif
    }

    private func beat() {
        if let last = Storage.lastPingAt(), Date().timeIntervalSince(last) < Self.heartbeatInterval { return }
        // Marked before the request, not after: a device that is opened while offline should not retry
        // on every foreground for the rest of the day. A missed beat costs a day of resolution on a
        // signal measured in days; a retry loop costs the user's battery.
        Storage.markPinged()
        let id = installId
        Task { await api.ping(installId: id) }
    }

    func trackAdRevenue(value: Double, currency: String, format: AdFormat) {
        // Read at the impression, not at install: eCPM is set by where the ad was served, and a user
        // who has travelled since installing would otherwise have every impression priced against the
        // country they signed up in.
        Task {
            let region = SDKEnvironment.currentRegion()
            await api.recordEvent(.ad(installId: installId, value: value, currency: currency,
                                      format: format, region: region))
        }
    }

    func trackCustomEvent(name: String, value: Double?) {
        Task { await api.recordCustomEvent(installId: installId, name: name, value: value) }
    }

}
