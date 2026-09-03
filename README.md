# sdk

Swift Package (`Asalyze`). On-device: captures Apple Search Ads attribution once on launch, auto-tracks
StoreKit 2 IAP, routes AdMob ad revenue, sends events to the backend. iOS 15+. Distributed via SPM +
CocoaPods. Links AdServices + StoreKit as **system frameworks** (not bundled); AdMob is hooked, not bundled.

## Layout (layered)
```
Sources/Asalyze/
├── Core/          configure(apiKey:appId:), Keychain install id, environment detection, models
├── Attribution/   AdServices token capture -> resolved server-side to campaign/adgroup/keyword
├── Revenue/       StoreKit 2 Transaction.updates observer; AdMob adapter
└── Networking/    ingest client -> POST /v1/install, /v1/event, /v1/subscription, /v1/custom-event
```

## Public surface
```swift
Asalyze.configure(apiKey: "sk_…", appId: "com.your.app")        // AdServices + StoreKit 2 auto
Asalyze.trackAdRevenue(valueUsd:format:currency:)               // e.g. from AdMob paidEventHandler
Asalyze.trackEvent("completed_onboarding")                      // custom event → Goals
```

Purchases are **not** in that list, deliberately. StoreKit 2 is observed automatically, using Apple's
own transaction id, price, currency, offer type and product type — more accurate than anything an app
can pass, and the transaction id is what makes deduplication possible. There is no manual purchase
call: one would take the app's word for the price and, used alongside the observer, count the same
money twice.

## Design note (R6-friendly)
Attribution capture sits behind its own module so a future SKAN conversion-value manager is added
alongside — never entangled with IAP/ad tracking.

## Status
Sources implemented (facade, Keychain-backed install id, TestFlight/sandbox environment detection,
AdServices capture, StoreKit 2 observer, AdMob helper, ingest client) + unit tests — **compiles and
passes `swift test` on the host.** A **Flutter plugin** wrapping this SDK lives in [`flutter/`](flutter/)
— same surface, iOS-only (no Android; ASA is iOS-only), not yet published (needs Xcode + Flutter).
The public API matches the dashboard's Developer Docs.

### Subscription transitions

**Cancelled, expired, resubscribed and offer-redeemed** reach Asalyze through **App Store Server
Notifications** and the App Store Server API. Renewal *status* is not a StoreKit transaction, so these
never appear in the transaction stream and there is nothing to report from the app.

Connect App Store Server Notifications and this is handled — including for users who never reopen the
app, which no on-device code can cover.

---

Built and maintained by [Codematics Services Private Limited](https://asalyze.com). Malik Ahsan Ali — Founder & Managing Director.
