import Flutter
import UIKit
import UserNotifications

/// UIScene + AppDelegate'da OLDINDAN yaratilgan Flutter dvigateli — ATAYLAB
/// (bola ilovasi `farzandim_child` bilan bir xil, iOS 27 da tekshirilgan).
///
/// • iOS 27 SDK bilan yig'ilgan ilova UIScene'siz ishga tushmaydi
///   (`_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption` crash).
/// • Storyboard'dagi implicit engine (`FlutterImplicitEngineDelegate`) bilan esa
///   plaginlar ilova ishga tushib BO'LGANDAN keyin ro'yxatdan o'tardi:
///   firebase_messaging 15.x `UIApplicationDidFinishLaunchingNotification`ni
///   kutib sozlanadi — APNs token olinmas va maktab push'lari (keldi / ketdi,
///   e'lonlar, to'lov) ota-onaga UMUMAN yetmasdi.
/// Shuning uchun dvigatel shu yerda yaratiladi va plaginlar `super`dan OLDIN
/// ro'yxatdan o'tadi; oynani SceneDelegate shu dvigatel bilan quradi.
@main
@objc class AppDelegate: FlutterAppDelegate {
  let flutterEngine = FlutterEngine(name: "parvoz")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    // flutter_local_notifications: ilova ochiq paytda ham bildirishnoma chiqsin
    // va bosilganda javob kelsin (FlutterAppDelegate hodisalarni plaginlarga uzatadi).
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
