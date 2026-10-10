import DeviceActivity
import FamilyControls
import Flutter
import SwiftUI

/// Family Controls (Screen Time API) — Dart `ScreenTimeChannel` bilan aloqa.
///
/// Metodlar:
///   • `status` → { authorization, blocking, apps, categories, webDomains }
///   • `requestAuthorization` → ota-ona Apple ID bilan tasdiqlaydi (.child)
///   • `pickApps` {title, cancel, done} → FamilyActivityPicker; null = bekor
///   • `applyPolicy` {blockAll, windows:[{start,end,weekdays}]} → jadvallar
///   • `reset` → uzish paytida hammasini tozalash
final class ScreenTimePlugin: NSObject, FlutterPlugin {
  private static let channelName = "uz.parvoz.growth/screen_time"
  /// DeviceActivityCenter bir vaqtda kuzatadigan jadvallar chegarasi
  /// (yarim tun jadvali uchun bitta joy qoldiriladi).
  private static let maxSchedules = 20
  /// Picker qayta ochilganda oldingi tanlov ko'rinsin (faqat ilova o'qiydi).
  private static let selectionKey = "screenTime.pickerSelection.v1"

  private var isPicking = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ScreenTimePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(Self.status())
    case "requestAuthorization":
      requestAuthorization(result)
    case "pickApps":
      pickApps(call.arguments as? [String: Any] ?? [:], result: result)
    case "applyPolicy":
      applyPolicy(call.arguments, result: result)
    case "reset":
      let center = DeviceActivityCenter()
      center.stopMonitoring(Self.managedActivities(center))
      ParvozShield.reset()
      UserDefaults(suiteName: ParvozShield.appGroupId)?.removeObject(forKey: Self.selectionKey)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Holat

  /// Yangi SDK'larda qo'shimcha "approved…" holatlari bor (masalan iOS 26.4
  /// `approvedWithDataAccess`) — rad etilmagan va aniqlangan har holat ruxsat.
  private static var isAuthorized: Bool {
    let status = AuthorizationCenter.shared.authorizationStatus
    return status != .denied && status != .notDetermined
  }

  private static func status() -> [String: Any] {
    let tokens = ParvozShield.loadTokens()
    return [
      "authorization": authorizationName(),
      "blocking": isAuthorized && ParvozShield.shouldBlock(),
      "apps": tokens.applications.count,
      "categories": tokens.categories.count,
      "webDomains": tokens.webDomains.count,
    ]
  }

  private static func authorizationName() -> String {
    switch AuthorizationCenter.shared.authorizationStatus {
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    default: return "approved"
    }
  }

  // MARK: Ruxsat

  private func requestAuthorization(_ result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .child)
        result(Self.status())
      } catch let error as FamilyControlsError {
        result(FlutterError(
          code: Self.errorCode(error),
          message: error.localizedDescription,
          details: nil
        ))
      } catch {
        result(FlutterError(code: "unknown", message: error.localizedDescription, details: nil))
      }
    }
  }

  private static func errorCode(_ error: FamilyControlsError) -> String {
    switch error {
    case .restricted: return "restricted"
    case .unavailable: return "unavailable"
    case .invalidAccountType: return "invalidAccountType"
    case .invalidArgument: return "invalidArgument"
    case .authorizationConflict: return "authorizationConflict"
    case .authorizationCanceled: return "authorizationCanceled"
    case .networkError: return "networkError"
    case .authenticationMethodUnavailable: return "authenticationMethodUnavailable"
    @unknown default: return "unknown"
    }
  }

  // MARK: Ilovalarni tanlash

  private func pickApps(_ args: [String: Any], result: @escaping FlutterResult) {
    guard Self.isAuthorized else {
      result(FlutterError(code: "notAuthorized", message: "Family Controls ruxsati yo'q", details: nil))
      return
    }
    guard !isPicking else {
      result(FlutterError(code: "busy", message: "Tanlash oynasi allaqachon ochiq", details: nil))
      return
    }
    // `present` bunday holatda jim e'tiborsiz qoldiriladi — natija hech
    // qachon qaytmay, Dart tomoni abadiy kutib qolardi.
    guard
      let presenter = Self.topViewController(),
      !presenter.isBeingDismissed,
      !presenter.isBeingPresented
    else {
      result(FlutterError(code: "noPresenter", message: "Oyna topilmadi", details: nil))
      return
    }

    isPicking = true
    weak var host: UIViewController?
    let view = ParvozPickerView(
      selection: Self.loadPickerSelection(),
      title: args["title"] as? String ?? "",
      cancelTitle: args["cancel"] as? String ?? "Cancel",
      doneTitle: args["done"] as? String ?? "Done"
    ) { [weak self] picked in
      guard let self, self.isPicking else { return }
      self.isPicking = false
      host?.dismiss(animated: true)
      guard let picked else {
        result(nil)
        return
      }
      do {
        try Self.savePickerSelection(picked)
        try ParvozShield.saveTokens(ParvozShieldTokens(
          applications: picked.applicationTokens,
          categories: picked.categoryTokens,
          webDomains: picked.webDomainTokens
        ))
        ParvozShield.enforce()
        result(Self.status())
      } catch {
        result(FlutterError(code: "saveFailed", message: error.localizedDescription, details: nil))
      }
    }
    let controller = UIHostingController(rootView: view)
    // Faqat "Bekor"/"Tayyor" tugmalari bilan yopiladi — natija albatta qaytadi.
    controller.isModalInPresentation = true
    host = controller
    presenter.present(controller, animated: true)
  }

  private static func loadPickerSelection() -> FamilyActivitySelection {
    guard
      let data = UserDefaults(suiteName: ParvozShield.appGroupId)?.data(forKey: selectionKey),
      let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    else { return FamilyActivitySelection() }
    return selection
  }

  private static func savePickerSelection(_ selection: FamilyActivitySelection) throws {
    try ParvozShield.appGroupDefaults().set(try JSONEncoder().encode(selection), forKey: selectionKey)
  }

  private static func topViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  // MARK: Siyosat

  private func applyPolicy(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let requested = Self.parsePolicy(arguments) else {
      result(FlutterError(code: "badArgs", message: "blockAll/windows kerak", details: nil))
      return
    }
    var policy = requested
    var errors: [String] = []
    if Self.isAuthorized {
      let sync = Self.syncSchedules(requested.windows)
      errors = sync.errors
      // Jadvali ro'yxatdan o'tmagan oyna saqlanmaydi: aks holda u ilova
      // tomonida yoqilib, kengaytma uni hech qachon o'chirmas edi.
      policy.windows = requested.windows.filter { sync.registered.contains($0.key.activityName) }
    }
    do {
      try ParvozShield.savePolicy(policy)
    } catch {
      result(FlutterError(code: "saveFailed", message: error.localizedDescription, details: nil))
      return
    }
    let isBlocking = Self.isAuthorized ? ParvozShield.enforce() : false
    result(["blocking": isBlocking, "scheduleErrors": errors])
  }

  private static func parsePolicy(_ arguments: Any?) -> ParvozShieldPolicy? {
    guard
      let args = arguments as? [String: Any],
      let blockAll = args["blockAll"] as? Bool,
      let rawWindows = args["windows"] as? [[String: Any]]
    else { return nil }
    let windows = rawWindows.compactMap { raw -> ParvozShieldPolicy.Window? in
      guard
        let start = raw["start"] as? Int, (0..<1440).contains(start),
        let end = raw["end"] as? Int, (0..<1440).contains(end),
        let weekdays = raw["weekdays"] as? [Int]
      else { return nil }
      let window = ParvozShieldPolicy.Window(
        startMinute: start,
        endMinute: end,
        weekdays: weekdays.filter { (1...7).contains($0) }
      )
      guard
        window.durationMinutes >= ParvozShieldPolicy.minimumWindowMinutes,
        !window.weekdays.isEmpty
      else { return nil }
      return window
    }
    return ParvozShieldPolicy(blockAll: blockAll, windows: windows)
  }

  private static func managedActivities(_ center: DeviceActivityCenter) -> [DeviceActivityName] {
    center.activities.filter { $0.rawValue.hasPrefix(ParvozShieldPolicy.activityPrefix) }
  }

  /// Har bir noyob (boshlanish, tugash) juftligi uchun bitta kunlik jadval +
  /// yarim tun jadvali. Faqat farq qiladiganlar to'xtatiladi/boshlanadi.
  /// Qaytaradi: hozir kuzatilayotgan oyna nomlari va xatolar.
  private static func syncSchedules(
    _ windows: [ParvozShieldPolicy.Window]
  ) -> (registered: Set<String>, errors: [String]) {
    var keys: [ParvozShieldPolicy.WindowKey] = []
    for window in windows where !keys.contains(window.key) {
      keys.append(window.key)
    }
    var errors: [String] = []
    let windowSlots = maxSchedules - 1
    if keys.count > windowSlots {
      errors.append("limit: \(keys.count - windowSlots) ta oyna kuzatilmaydi")
      keys = Array(keys.prefix(windowSlots))
    }

    var schedules: [String: DeviceActivitySchedule] = [:]
    for key in keys {
      schedules[key.activityName] = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: key.startMinute / 60, minute: key.startMinute % 60),
        intervalEnd: DateComponents(hour: key.endMinute / 60, minute: key.endMinute % 60),
        repeats: true
      )
    }
    if !schedules.isEmpty {
      schedules[ParvozShieldPolicy.midnightTick] = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 0, minute: ParvozShieldPolicy.minimumWindowMinutes),
        repeats: true
      )
    }

    let center = DeviceActivityCenter()
    let current = Set(managedActivities(center).map(\.rawValue))
    let wanted = Set(schedules.keys)
    let stale = current.subtracting(wanted)
    if !stale.isEmpty {
      center.stopMonitoring(stale.map { DeviceActivityName($0) })
    }
    var registered = current.intersection(wanted)
    for name in wanted.subtracting(current) {
      guard let schedule = schedules[name] else { continue }
      do {
        try center.startMonitoring(DeviceActivityName(name), during: schedule)
        registered.insert(name)
      } catch {
        errors.append("\(name): \(error.localizedDescription)")
      }
    }
    return (registered, errors)
  }
}

/// FamilyActivityPicker'ni Flutter ustida ochish uchun SwiftUI o'rami.
private struct ParvozPickerView: View {
  @State var selection: FamilyActivitySelection
  let title: String
  let cancelTitle: String
  let doneTitle: String
  let onFinish: (FamilyActivitySelection?) -> Void

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(cancelTitle) { onFinish(nil) }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(doneTitle) { onFinish(selection) }
          }
        }
    }
    .navigationViewStyle(.stack)
  }
}
