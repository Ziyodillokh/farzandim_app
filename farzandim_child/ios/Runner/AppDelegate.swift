import CoreLocation
import Flutter
import UIKit
import UserNotifications

/// UIScene + AppDelegate'da OLDINDAN yaratilgan Flutter dvigateli — ATAYLAB.
///
/// • iOS 27 SDK bilan yig'ilgan ilova UIScene'siz ishga tushmaydi
///   (`_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption` crash,
///   iOS 27 simulyatorida tasdiqlangan) — klassik tartibga qaytib bo'lmaydi.
/// • Storyboard'dagi implicit engine (`FlutterImplicitEngineDelegate`) bilan esa
///   plaginlar ilova ishga tushib BO'LGANDAN keyin ro'yxatdan o'tardi:
///   firebase_messaging 15.x `UIApplicationDidFinishLaunchingNotification`ni
///   kutib sozlanadi — APNs token, bildirishnoma delegati va jim push
///   (`restrictions_sync`, `location_wake`) Dart'ga UMUMAN yetmasdi;
///   flutter_foreground_task ham fon vazifasini shu callback'da ro'yxatdan
///   o'tkazadi.
/// Shuning uchun dvigatel shu yerda yaratiladi va plaginlar `super`dan OLDIN
/// ro'yxatdan o'tadi; oynani SceneDelegate shu dvigatel bilan quradi. Fonda
/// (scene'siz) qayta ishga tushganda ham Dart `main()` ishlaydi.
@main
@objc class AppDelegate: FlutterAppDelegate {
  let flutterEngine = FlutterEngine(name: "parvoz")
  private let locationRelauncher = LocationRelauncher()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    if let registrar = flutterEngine.registrar(forPlugin: "MotionStepsPlugin") {
      MotionStepsPlugin.register(with: registrar)
    }
    if let registrar = flutterEngine.registrar(forPlugin: "ScreenTimePlugin") {
      ScreenTimePlugin.register(with: registrar)
    }
    // flutter_local_notifications: ilova ichida ko'rsatilgan bildirishnoma
    // ochiq paytda ham chiqsin va bosilganda javob kelsin (FlutterAppDelegate
    // hodisalarni plaginlarga uzatadi).
    UNUserNotificationCenter.current().delegate = self
    locationRelauncher.start()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// "Har doim" joylashuv ruxsati bo'lsa — sezilarli joy o'zgarishi monitoringi.
/// Ilova yopilgan/xotiradan chiqarilgan bo'lsa iOS uni shu hodisa bilan fonda
/// qayta ishga tushiradi: Dart `main()` ishlaydi, joylashuv oqimi va cheklovlar
/// sync'i qayta boshlanadi. Joylashuvning o'zi geolocator orqali yuboriladi.
private final class LocationRelauncher: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()

  func start() {
    manager.delegate = self
    update()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    update()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

  private func update() {
    guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
    if manager.authorizationStatus == .authorizedAlways {
      manager.startMonitoringSignificantLocationChanges()
    } else {
      manager.stopMonitoringSignificantLocationChanges()
    }
  }
}
