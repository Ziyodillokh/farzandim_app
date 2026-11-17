import CoreMotion
import Flutter

/// Bugungi qadam jami — CoreMotion (`CMPedometer`), HealthKit'siz.
///
/// Android'dagi Health Connect o'rnini bosadi: `pedometer` plagini iOS'da faqat
/// "qayta yoqilgandan beri" sonni beradi, bu esa kunning boshini bilmaydi.
/// `queryPedometerData(from:to:)` iPhone 7 kunlik tarixidan istalgan oraliqni
/// qaytaradi — shuning uchun ilova ochilmagan paytdagi qadamlar ham sanaladi.
/// Ruxsat — Motion & Fitness (NSMotionUsageDescription), Dart tomonda
/// `Permission.sensors` orqali so'raladi.
final class MotionStepsPlugin: NSObject, FlutterPlugin {
  private static let channelName = "uz.parvoz.growth/motion"
  private let pedometer = CMPedometer()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(MotionStepsPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(CMPedometer.isStepCountingAvailable())
    case "stepsBetween":
      stepsBetween(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func stepsBetween(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let args = arguments as? [String: Any],
      let startMs = (args["startMs"] as? NSNumber)?.doubleValue,
      let endMs = (args["endMs"] as? NSNumber)?.doubleValue,
      startMs < endMs
    else {
      result(FlutterError(code: "bad_args", message: "startMs < endMs kerak", details: nil))
      return
    }
    guard CMPedometer.authorizationStatus() == .authorized else {
      result(FlutterError(code: "not_authorized", message: "Motion ruxsati yo'q", details: nil))
      return
    }

    let start = Date(timeIntervalSince1970: startMs / 1000)
    let end = Date(timeIntervalSince1970: endMs / 1000)
    pedometer.queryPedometerData(from: start, to: end) { data, error in
      DispatchQueue.main.async {
        if let error = error as NSError? {
          result(FlutterError(
            code: "query_failed",
            message: error.localizedDescription,
            details: error.code
          ))
          return
        }
        result(data?.numberOfSteps.intValue ?? 0)
      }
    }
  }
}
