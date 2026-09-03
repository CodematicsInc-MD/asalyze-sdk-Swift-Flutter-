import Foundation
#if canImport(AdServices)
import AdServices
#endif

/// Captures Apple's AdServices attribution token on EVERY launch, not just the first. That matters:
/// AdServices usually has nothing to give in the seconds after an install, so the first call often
/// returns nil and a later one succeeds — the backend keeps the first token it receives and re-asks
/// Apple when a genuinely different one arrives. The token is opaque; our backend exchanges it with
/// Apple to resolve the deterministic campaign → ad group → keyword. No IDFA, no ATT prompt.
///
/// This lives behind its own type so a future SKAdNetwork / AdAttributionKit conversion-value manager
/// can be added alongside it, never entangled with IAP/ad tracking (see R6 in the architecture docs).
enum AttributionManager {
    /// The AdServices token, plus WHY there isn't one when there isn't.
    ///
    /// Apple's error is captured rather than discarded, and sent with the install. A device that could
    /// not produce a token is otherwise indistinguishable from one that was never asked, so a gap in
    /// attribution can be traced to a cause instead of guessed at.
    static func attributionToken() -> (token: String?, error: String?) {
        #if canImport(AdServices)
        if #available(iOS 14.3, *) {
            do {
                return (try AAAttribution.attributionToken(), nil)
            } catch {
                // Apple's AttributionError is an NSError underneath; domain+code is stable and small,
                // where a localizedDescription is localised and useless to group on.
                let ns = error as NSError
                return (nil, "\(ns.domain):\(ns.code)")
            }
        }
        return (nil, "os_below_14_3")
        #else
        return (nil, "framework_unavailable")
        #endif
    }
}
