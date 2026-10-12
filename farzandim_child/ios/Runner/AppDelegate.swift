import CoreLocation
import Flutter
import UIKit
import UserNotifications

/// Klassik (UIScene'siz) ishga tushish — ATAYLAB.
///
/// UIScene + `FlutterImplicitEngineDelegate` bilan plaginlar ilova ishga
/// tushib BO'LGANDAN keyin ro'yxatdan o'tardi. firebase_messaging 15.x esa
/// `UIApplicationDidFinishLaunchingNotification`ni kutib sozlanadi — signal
/// o'tib ketgani uchun APNs ro'yxati, bildirishnoma delegati va jim push
/// (`restrictions_sync`, `location_wake`) Dart'ga UMUMAN yetmasdi.
/// flutter_foreground_task 8.x ham fon vazifasini shu yerda ro'yxatdan
/// o'tkazadi. Bu yerda plaginlar `super`dan OLDIN ro'yxatdan o'tadi.
/// UIScene'ga qaytish: firebase_messaging >= 16.7 va flutter_foreground_task
/// >= 10 dan keyin.
@main
@objc class AppDelegate: FlutterAppDelegate {
  private let locationRelauncher = LocationRelauncher()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "MotionStepsPlugin") {
      MotionStepsPlugin.register(with: registrar)
    }
    if let registrar = registrar(forPlugin: "ScreenTimePlugin") {
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
