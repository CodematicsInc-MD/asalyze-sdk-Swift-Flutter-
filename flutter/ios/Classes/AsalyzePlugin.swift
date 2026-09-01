import Flutter
import UIKit

/// Bridges the Flutter MethodChannel to the native Asalyze SDK. The native SDK sources are vendored
/// under `Classes/native/` and compiled into this same pod module, so there's no external dependency
/// and no `import Asalyze` — the types (`Asalyze`, `AdFormat`, …) are in-module.
public class AsalyzePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "asalyze", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(AsalyzePlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "configure":
            guard let apiKey = args["apiKey"] as? String, let appId = args["appId"] as? String else {
                return result(FlutterError(code: "bad_args", message: "apiKey and appId required", details: nil))
            }
            // Optional endpoint override (local/staging backend). Defaults to production when omitted.
            let endpoint = (args["endpoint"] as? String).flatMap { URL(string: $0) } ?? Config.defaultEndpoint
            Asalyze.configure(apiKey: apiKey, appId: appId, endpoint: endpoint)
            result(nil)

        case "installId":
            result(Asalyze.installId)

        case "setUserId":
            Asalyze.setUserId(args["userId"] as? String)
            result(nil)

        case "trackAdRevenue":
            let value = args["valueUsd"] as? Double ?? 0
            let currency = args["currency"] as? String ?? "USD"
            let format = AdFormat(rawValue: args["format"] as? String ?? "banner") ?? .banner
            Asalyze.trackAdRevenue(valueUsd: value, format: format, currency: currency)
            result(nil)

        case "trackEvent":
            guard let name = args["name"] as? String else {
                return result(FlutterError(code: "bad_args", message: "name required", details: nil))
            }
            Asalyze.trackEvent(name, valueUsd: args["valueUsd"] as? Double)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
