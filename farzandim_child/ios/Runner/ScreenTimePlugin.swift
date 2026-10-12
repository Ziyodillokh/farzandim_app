import DeviceActivity
import FamilyControls
import Flutter
import SwiftUI

/// Family Controls (Screen Time API) — Dart `ScreenTimeChannel` bilan aloqa.
///
/// Metodlar:
///   • `status` → { authorization, blocking, apps, categories, webDomains }
///   • `requestAuthorization` {mode} → "individual" (Face ID/parol, standart)
///     yoki "child" (kuchli himoya: Family Sharing, ota-ona Apple ID)
///   • `pickApps` {title, cancel, done} → FamilyActivityPicker; null = bekor
///   • `applyPolicy` {blockAll, windows:[{start,end,weekdays}], dailyLimitMinutes?,
///     denyAppRemoval?, language}
///   • `grantUnlock` {untilMs, minutes} / `clearUnlock` → ota-ona bergan vaqt
///   • `setExtras` {blockAdultWebsites, denyAppInstallation}
///   • `consumePendingUnlockRequest` → bloklash ekranida vaqt so'ralganmi
///   • `reset` → uzish paytida hammasini tozalash
final class ScreenTimePlugin: NSObject, FlutterPlugin {
  private static let channelName = "uz.parvoz.growth/screen_time"
  /// DeviceActivityCenter bir vaqtda kuzatadigan jadvallar chegarasi.
  private static let maxSchedules = 20
  /// Oyna bo'lmagan jadvallar: yarim tun, qo'shimcha vaqt, kunlik limit.
  private static let reservedSchedules = 3
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
      let mode = (call.arguments as? [String: Any])?["mode"] as? String
      requestAuthorization(member: mode == "child" ? .child : .individual, result: result)
    case "pickApps":
      pickApps(call.arguments as? [String: Any] ?? [:], result: result)
    case "applyPolicy":
      applyPolicy(call.arguments, result: result)
    case "grantUnlock":
      grantUnlock(call.arguments, result: result)
    case "clearUnlock":
      Self.clearUnlock()
      result(Self.status())
    case "setExtras":
      setExtras(call.arguments, result: result)
    case "consumePendingUnlockRequest":
      result(ParvozShield.consumeUnlockRequest())
    case "reset":
      let center = DeviceActivityCenter()
      center.stopMonitoring(center.activities.filter {
        $0.rawValue.hasPrefix(ParvozShieldPolicy.activityPrefix)
      })
      ParvozShield.reset()
      // `reset` hamma "parvoz." jadvallarini to'xtatdi (kunlik limit ham).
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
    let extras = ParvozShield.loadExtras()
    var status: [String: Any] = [
      "authorization": authorizationName(),
      "blocking": isAuthorized && ParvozShield.shouldBlock(),
      "apps": tokens.applications.count,
      "categories": tokens.categories.count,
      "webDomains": tokens.webDomains.count,
      "blockAdultWebsites": extras.blockAdultWebsites,
      "denyAppInstallation": extras.denyAppInstallation,
    ]
    if ParvozShield.isUnlocked(), let until = ParvozShield.unlockUntil() {
      status["unlockedUntilMs"] = Int(until.timeIntervalSince1970 * 1000)
    }
    if let limit = ParvozShield.loadPolicy().dailyLimitMinutes {
      status["dailyLimitMinutes"] = limit
      status["dailyLimitReached"] = ParvozShield.isDailyLimitReached()
    }
    return status
  }

  private static func authorizationName() -> String {
    switch AuthorizationCenter.shared.authorizationStatus {
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    default: return "approved"
    }
  }

  // MARK: Ruxsat

  /// `.individual` — telefon egasi Face ID/parol bilan tasdiqlaydi (Oila
  /// guruhi kerak emas, lekin Sozlamalardan bekor qilinishi mumkin).
  /// `.child` — Family Sharing'dagi bola akkaunti, ota-ona Apple ID bilan.
  private func requestAuthorization(
    member: FamilyControlsMember,
    result: @escaping FlutterResult
  ) {
    Task { @MainActor in
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: member)
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
      let previousTokens = ParvozShield.loadTokens()
      do {
        try Self.savePickerSelection(picked)
        try ParvozShield.saveTokens(ParvozShieldTokens(
          applications: picked.applicationTokens,
          categories: picked.categoryTokens,
          webDomains: picked.webDomainTokens
        ))
        // Kunlik limit hodisasi token'lar bilan ro'yxatdan o'tadi — tanlov
        // o'zgargan bo'lsagina qayta boshlanadi.
        _ = Self.syncDailyLimit(
          ParvozShield.loadPolicy().dailyLimitMinutes,
          isRestartNeeded: ParvozShield.loadTokens() != previousTokens
        )
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
    if let language = (arguments as? [String: Any])?["language"] as? String {
      ParvozShield.setLanguage(language)
    }
    var policy = requested
    var errors: [String] = []
    let previousLimit = ParvozShield.loadPolicy().dailyLimitMinutes
    if previousLimit != requested.dailyLimitMinutes {
      // Ota-ona limitni o'zgartirdi/olib tashladi — bugungi "tugadi" belgisi bekor.
      ParvozShield.setDailyLimitReached(false)
    }
    if Self.isAuthorized {
      let sync = Self.syncSchedules(requested.windows)
      errors = sync.errors
      errors += Self.syncDailyLimit(
        requested.dailyLimitMinutes,
        isRestartNeeded: previousLimit != requested.dailyLimitMinutes
      )
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
    if Self.isAuthorized {
      // Doimiy himoya har sync'da qayta qo'llanadi (tizim tiklangan bo'lsa
      // ham) — saqlangan siyosatdagi "o'chirishdan himoya" bilan birga.
      ParvozShield.applyExtras(ParvozShield.loadExtras())
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
    var dailyLimit: Int?
    if let minutes = args["dailyLimitMinutes"] as? Int, (1..<1440).contains(minutes) {
      dailyLimit = minutes
    }
    return ParvozShieldPolicy(
      blockAll: blockAll,
      windows: windows,
      dailyLimitMinutes: dailyLimit,
      denyAppRemoval: args["denyAppRemoval"] as? Bool
    )
  }

  // MARK: Kunlik limit

  /// Kunlik limit jadvali: har kuni 00:00–23:59, tanlangan ilovalardan
  /// [minutes] daqiqa foydalanilganda kengaytma cheklovni yoqadi. Jadval
  /// faqat limit/tanlov o'zgarganda qayta boshlanadi. iOS 17.4+ da bugungi
  /// oldingi foydalanish ham hisoblanadi; eskisida qayta boshlash hisobni
  /// noldan boshlaydi (shuning uchun keraksiz qayta boshlanmaydi).
  private static func syncDailyLimit(_ minutes: Int?, isRestartNeeded: Bool) -> [String] {
    let center = DeviceActivityCenter()
    let activity = DeviceActivityName(ParvozShield.dailyActivity)
    let tokens = ParvozShield.loadTokens()
    guard let minutes, !tokens.isEmpty else {
      center.stopMonitoring([activity])
      return []
    }
    let isMonitoring = center.activities.contains(activity)
    if isMonitoring && !isRestartNeeded { return [] }
    center.stopMonitoring([activity])
    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
      intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
      repeats: true
    )
    let threshold = DateComponents(minute: minutes)
    let event: DeviceActivityEvent
    if #available(iOS 17.4, *) {
      event = DeviceActivityEvent(
        applications: tokens.applications,
        categories: tokens.categories,
        webDomains: tokens.webDomains,
        threshold: threshold,
        includesPastActivity: true
      )
    } else {
      event = DeviceActivityEvent(
        applications: tokens.applications,
        categories: tokens.categories,
        webDomains: tokens.webDomains,
        threshold: threshold
      )
    }
    do {
      try center.startMonitoring(
        activity,
        during: schedule,
        events: [DeviceActivityEvent.Name(ParvozShield.dailyLimitEvent): event]
      )
      return []
    } catch {
      return ["\(ParvozShield.dailyActivity): \(error.localizedDescription)"]
    }
  }

  /// Jadval oynalari va yarim tun jadvali (vaqtinchalik ruxsat jadvali emas).
  private static func managedActivities(_ center: DeviceActivityCenter) -> [DeviceActivityName] {
    center.activities.filter {
      $0.rawValue.hasPrefix(ParvozShieldPolicy.WindowKey.prefix)
        || $0.rawValue == ParvozShieldPolicy.midnightTick
    }
  }

  // MARK: Vaqtinchalik ruxsat (ota-ona tasdiqlagan qo'shimcha vaqt)

  /// `untilMs` gacha cheklov ochiladi. Ilova yopiq bo'lsa ham o'z vaqtida
  /// qaytishi uchun: jadval oxiri = max(until, hozir + 15 daqiqa) (Apple
  /// minimumi) va cheklangan ilovalardan `minutes` daqiqa foydalanilganda
  /// hodisa — qaysi biri oldin kelsa, kengaytma cheklovni qayta yoqadi.
  private func grantUnlock(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let args = arguments as? [String: Any],
      let untilMs = (args["untilMs"] as? NSNumber)?.doubleValue,
      let minutes = args["minutes"] as? Int, minutes > 0
    else {
      result(FlutterError(code: "badArgs", message: "untilMs/minutes kerak", details: nil))
      return
    }
    let now = Date()
    let until = Date(timeIntervalSince1970: untilMs / 1000)
    guard until > now else {
      Self.clearUnlock()
      result(Self.status())
      return
    }
    // Xuddi shu ruxsat allaqachon qo'llangan — jadvalni qayta boshlamaymiz
    // (foydalanish hisobi noldan boshlanib ketmasin).
    if let current = ParvozShield.unlockUntil(), abs(current.timeIntervalSince(until)) < 1 {
      result(Self.status())
      return
    }
    do {
      try ParvozShield.setUnlockUntil(until)
    } catch {
      result(FlutterError(code: "saveFailed", message: error.localizedDescription, details: nil))
      return
    }
    var errors: [String] = []
    if Self.isAuthorized {
      errors = Self.scheduleUnlockEnd(now: now, until: until, minutes: minutes)
      ParvozShield.enforce(now: now)
    }
    var status = Self.status()
    status["scheduleErrors"] = errors
    result(status)
  }

  private static func scheduleUnlockEnd(now: Date, until: Date, minutes: Int) -> [String] {
    let center = DeviceActivityCenter()
    let activity = DeviceActivityName(ParvozShield.unlockActivity)
    center.stopMonitoring([activity])
    let minimumEnd = now.addingTimeInterval(TimeInterval(ParvozShieldPolicy.minimumWindowMinutes * 60))
    let end = max(until, minimumEnd)
    let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    let calendar = Calendar.autoupdatingCurrent
    let schedule = DeviceActivitySchedule(
      intervalStart: calendar.dateComponents(components, from: now),
      intervalEnd: calendar.dateComponents(components, from: end),
      repeats: false
    )
    let tokens = ParvozShield.loadTokens()
    let event = DeviceActivityEvent(
      applications: tokens.applications,
      categories: tokens.categories,
      webDomains: tokens.webDomains,
      threshold: DateComponents(minute: minutes)
    )
    do {
      try center.startMonitoring(
        activity,
        during: schedule,
        events: [DeviceActivityEvent.Name(ParvozShield.unlockLimitEvent): event]
      )
      return []
    } catch {
      return ["\(ParvozShield.unlockActivity): \(error.localizedDescription)"]
    }
  }

  private static func clearUnlock() {
    DeviceActivityCenter().stopMonitoring([DeviceActivityName(ParvozShield.unlockActivity)])
    try? ParvozShield.setUnlockUntil(nil)
    if isAuthorized {
      ParvozShield.enforce()
    }
  }

  // MARK: Doimiy himoya

  private func setExtras(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let args = arguments as? [String: Any],
      let blockAdultWebsites = args["blockAdultWebsites"] as? Bool,
      let denyAppInstallation = args["denyAppInstallation"] as? Bool
    else {
      result(FlutterError(code: "badArgs", message: "extras kerak", details: nil))
      return
    }
    guard Self.isAuthorized else {
      result(FlutterError(code: "notAuthorized", message: "Family Controls ruxsati yo'q", details: nil))
      return
    }
    do {
      try ParvozShield.saveExtras(ParvozShieldExtras(
        blockAdultWebsites: blockAdultWebsites,
        denyAppInstallation: denyAppInstallation
      ))
      result(Self.status())
    } catch {
      result(FlutterError(code: "saveFailed", message: error.localizedDescription, details: nil))
    }
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
    let windowSlots = maxSchedules - reservedSchedules
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
