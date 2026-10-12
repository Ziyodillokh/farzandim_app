import Foundation
import ManagedSettings
import os

// ─────────────────────────────────────────────────────────────────────
// ParvozShield — Runner va ParvozMonitor kengaytmasi uchun UMUMIY mantiq
// ─────────────────────────────────────────────────────────────────────
//
// Apple Family Controls shartlari bo'yicha:
//   • tanlangan ilovalar (opaque token'lar) FAQAT shu qurilmada, App Group
//     UserDefaults'da saqlanadi — serverga hech qachon yuborilmaydi;
//   • backend'dan faqat ilova-nomisiz siyosat keladi: "hammasini bloklash",
//     vaqt oynalari (ota-ona jadvali) va tanlangan ilovalarga kunlik limit.
// Cheklov holati har safar siyosat + joriy vaqtdan qayta hisoblanadi, shuning
// uchun ilova va kengaytma bir xil natijaga keladi.
//
// Bu fayl faqat ManagedSettings'ga tayanadi (FamilyControls/SwiftUI emas) —
// DeviceActivityMonitor kengaytmasining ~6 MB xotira chegarasi uchun.

/// Cheklanadigan token'lar (FamilyActivitySelection'dan, ilova tomonda olinadi).
struct ParvozShieldTokens: Codable, Equatable {
  var applications: Set<ApplicationToken>
  var categories: Set<ActivityCategoryToken>
  var webDomains: Set<WebDomainToken>

  static let empty = ParvozShieldTokens(applications: [], categories: [], webDomains: [])

  var isEmpty: Bool { applications.isEmpty && categories.isEmpty && webDomains.isEmpty }
}

/// Jadvaldan mustaqil, doimiy himoya (ota-ona PIN bilan yoqadi).
struct ParvozShieldExtras: Codable, Equatable {
  var blockAdultWebsites: Bool
  var denyAppInstallation: Bool

  static let off = ParvozShieldExtras(blockAdultWebsites: false, denyAppInstallation: false)
}

enum ParvozShieldError: Error {
  /// App Group entitlement yo'q yoki noto'g'ri — saqlash imkonsiz.
  case appGroupUnavailable
}

enum ParvozShield {
  static let appGroupId = "group.uz.parvoz.growth"
  /// Apple: `shield.applications` bir vaqtda ko'pi bilan 50 ta ilova.
  static let maxShieldedApps = 50

  /// Vaqtinchalik ruxsat (ota-ona tasdiqlagan qo'shimcha vaqt) jadvali.
  static let unlockActivity = "parvoz.unlock"
  static let unlockLimitEvent = "parvoz.unlock.limit"
  /// Kunlik limit: har kuni 00:00–23:59 jadvali va tanlangan ilovalardan
  /// limit daqiqa foydalanilganda keladigan hodisa.
  static let dailyActivity = "parvoz.daily"
  static let dailyLimitEvent = "parvoz.daily.limit"
  /// Bloklash ekranidagi "vaqt so'rash" belgisi shuncha vaqt amal qiladi.
  static let pendingRequestTTL: TimeInterval = 30 * 60

  private static let tokensKey = "screenTime.tokens.v1"
  private static let policyKey = "screenTime.policy.v1"
  private static let extrasKey = "screenTime.extras.v1"
  private static let unlockUntilKey = "screenTime.unlockUntil.v1"
  private static let pendingRequestKey = "screenTime.pendingUnlockRequest.v1"
  private static let languageKey = "screenTime.language.v1"
  /// Kunlik limit tugagan belgisi shu paytgacha amal qiladi (limit tugagan
  /// kundan keyingi yarim tun, Unix soniya). Mutlaq vaqt — vaqt mintaqasi
  /// almashsa ham belgi yo'qolmaydi.
  private static let dailyLimitReachedKey = "screenTime.dailyLimitReachedUntil.v1"
  private static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("parvoz"))
  private static let log = Logger(subsystem: "uz.parvoz.growth", category: "ParvozShield")

  // MARK: Saqlash

  static func appGroupDefaults() throws -> UserDefaults {
    guard let defaults = UserDefaults(suiteName: appGroupId) else {
      throw ParvozShieldError.appGroupUnavailable
    }
    return defaults
  }

  static func loadTokens() -> ParvozShieldTokens {
    decode(ParvozShieldTokens.self, key: tokensKey) ?? .empty
  }

  static func saveTokens(_ tokens: ParvozShieldTokens) throws {
    try appGroupDefaults().set(try JSONEncoder().encode(tokens), forKey: tokensKey)
  }

  static func loadPolicy() -> ParvozShieldPolicy {
    decode(ParvozShieldPolicy.self, key: policyKey) ?? .none
  }

  static func savePolicy(_ policy: ParvozShieldPolicy) throws {
    try appGroupDefaults().set(try JSONEncoder().encode(policy), forKey: policyKey)
  }

  static func loadExtras() -> ParvozShieldExtras {
    decode(ParvozShieldExtras.self, key: extrasKey) ?? .off
  }

  /// Saqlaydi va darhol qo'llaydi (jadvalga bog'liq emas).
  static func saveExtras(_ extras: ParvozShieldExtras) throws {
    try appGroupDefaults().set(try JSONEncoder().encode(extras), forKey: extrasKey)
    applyExtras(extras)
  }

  /// Doimiy himoya (bola qurilmasida PIN bilan) + ota-onaning
  /// "O'chirishdan himoya"si (backend siyosati) — jadvaldan mustaqil.
  static func applyExtras(_ extras: ParvozShieldExtras) {
    store.webContent.blockedByFilter = extras.blockAdultWebsites ? .auto() : nil
    store.application.denyAppInstallation = extras.denyAppInstallation ? true : nil
    store.application.denyAppRemoval = loadPolicy().denyAppRemoval == true ? true : nil
    // Jadval va kunlik limit soatga tayanadi — bola sana/vaqtni qo'lda
    // surib cheklovni aylanib o'tmasin ("Avtomatik" doim yoqiq).
    store.dateAndTime.requireAutomaticDateAndTime = true
  }

  // MARK: Vaqtinchalik ruxsat

  static func unlockUntil() -> Date? {
    let value = UserDefaults(suiteName: appGroupId)?.double(forKey: unlockUntilKey) ?? 0
    return value > 0 ? Date(timeIntervalSince1970: value) : nil
  }

  static func isUnlocked(now: Date = Date()) -> Bool {
    guard let until = unlockUntil() else { return false }
    return until > now
  }

  static func setUnlockUntil(_ until: Date?) throws {
    let defaults = try appGroupDefaults()
    if let until {
      defaults.set(until.timeIntervalSince1970, forKey: unlockUntilKey)
    } else {
      defaults.removeObject(forKey: unlockUntilKey)
    }
  }

  // MARK: Bloklash ekranidan "vaqt so'rash"

  static func markUnlockRequested(now: Date = Date()) {
    UserDefaults(suiteName: appGroupId)?.set(now.timeIntervalSince1970, forKey: pendingRequestKey)
  }

  /// Belgi bo'lsa va eskirmagan bo'lsa `true` qaytaradi va uni o'chiradi.
  static func consumeUnlockRequest(now: Date = Date()) -> Bool {
    guard let defaults = UserDefaults(suiteName: appGroupId) else { return false }
    let markedAt = defaults.double(forKey: pendingRequestKey)
    defaults.removeObject(forKey: pendingRequestKey)
    guard markedAt > 0 else { return false }
    return now.timeIntervalSince1970 - markedAt < pendingRequestTTL
  }

  // MARK: Kunlik limit

  static func isDailyLimitReached(now: Date = Date()) -> Bool {
    let until = UserDefaults(suiteName: appGroupId)?.double(forKey: dailyLimitReachedKey) ?? 0
    return now.timeIntervalSince1970 < until
  }

  /// `true` — limit tugadi, belgi keyingi yarim tungacha amal qiladi;
  /// `false` — belgi o'chiriladi (ota-ona limitni o'zgartirdi/olib tashladi).
  static func setDailyLimitReached(
    _ isReached: Bool,
    now: Date = Date(),
    calendar: Calendar = .autoupdatingCurrent
  ) {
    let defaults = UserDefaults(suiteName: appGroupId)
    guard
      isReached,
      let until = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
    else {
      defaults?.removeObject(forKey: dailyLimitReachedKey)
      return
    }
    defaults?.set(until.timeIntervalSince1970, forKey: dailyLimitReachedKey)
  }

  // MARK: Til (bloklash ekrani va eslatma matnlari uchun)

  static func language() -> ParvozShieldLanguage {
    let code = UserDefaults(suiteName: appGroupId)?.string(forKey: languageKey) ?? ""
    return ParvozShieldLanguage(code: code)
  }

  static func setLanguage(_ code: String) {
    UserDefaults(suiteName: appGroupId)?.set(code, forKey: languageKey)
  }

  /// Uzish (unpair) paytida — token'lar, siyosat va barcha cheklovlar o'chadi.
  static func reset() {
    let defaults = UserDefaults(suiteName: appGroupId)
    for key in [tokensKey, policyKey, extrasKey, unlockUntilKey, pendingRequestKey, dailyLimitReachedKey] {
      defaults?.removeObject(forKey: key)
    }
    store.clearAllSettings()
  }

  private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
    guard let data = UserDefaults(suiteName: appGroupId)?.data(forKey: key) else { return nil }
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      log.error("\(key, privacy: .public) o'qilmadi: \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }

  // MARK: Qo'llash

  /// Hozir cheklov bo'lishi kerakmi (qo'llamaydi).
  static func shouldBlock(
    now: Date = Date(),
    started: ParvozShieldPolicy.WindowKey? = nil,
    ended: ParvozShieldPolicy.WindowKey? = nil
  ) -> Bool {
    !isUnlocked(now: now)
      && !loadTokens().isEmpty
      && isPolicyBlocking(now: now, started: started, ended: ended)
  }

  /// Jadval/"hammasini bloklash" yoki bugungi kunlik limit tugagan.
  private static func isPolicyBlocking(
    now: Date,
    started: ParvozShieldPolicy.WindowKey?,
    ended: ParvozShieldPolicy.WindowKey?
  ) -> Bool {
    let policy = loadPolicy()
    if policy.dailyLimitMinutes != nil, isDailyLimitReached(now: now) { return true }
    return policy.isBlocking(at: now, started: started, ended: ended)
  }

  /// Siyosat va tanlov bo'yicha shield'ni yoqadi yoki o'chiradi.
  /// `started`/`ended` — DeviceActivity chaqiruvi qaysi oyna uchun kelgani
  /// (soniyalik kechikishda ham oyna to'g'ri hisoblansin).
  @discardableResult
  static func enforce(
    now: Date = Date(),
    started: ParvozShieldPolicy.WindowKey? = nil,
    ended: ParvozShieldPolicy.WindowKey? = nil
  ) -> Bool {
    let tokens = loadTokens()
    guard
      !isUnlocked(now: now),
      !tokens.isEmpty,
      isPolicyBlocking(now: now, started: started, ended: ended)
    else {
      clearShield()
      return false
    }
    store.shield.applications = tokens.applications.isEmpty
      ? nil : cappedApplications(tokens.applications)
    store.shield.applicationCategories = tokens.categories.isEmpty
      ? nil : .specific(tokens.categories)
    store.shield.webDomainCategories = tokens.categories.isEmpty
      ? nil : .specific(tokens.categories)
    store.shield.webDomains = tokens.webDomains.isEmpty ? nil : tokens.webDomains
    return true
  }

  static func clearShield() {
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    store.shield.webDomains = nil
    store.shield.webDomainCategories = nil
  }

  /// 50 tadan ko'p bo'lsa — DETERMINISTIK tartibda birinchi 50 tasi, shunda
  /// ilova va kengaytma (alohida jarayonlar) bir xil to'plamni cheklaydi.
  private static func cappedApplications(_ apps: Set<ApplicationToken>) -> Set<ApplicationToken> {
    guard apps.count > maxShieldedApps else { return apps }
    let encoder = JSONEncoder()
    let ordered = apps
      .map { (token: $0, key: (try? encoder.encode($0))?.base64EncodedString() ?? "") }
      .sorted { $0.key < $1.key }
    return Set(ordered.prefix(maxShieldedApps).map(\.token))
  }
}

/// Backend'dan keladigan, ilova nomlarisiz siyosat. Vaqt — qurilma mahalliy
/// vaqti (Android RestrictionsSyncService bilan bir xil semantika).
struct ParvozShieldPolicy: Codable, Equatable {
  /// DeviceActivitySchedule eng qisqa oraliq (Apple: 15 daqiqa).
  static let minimumWindowMinutes = 15

  /// Barcha Parvoz DeviceActivity nomlari shu prefiks bilan boshlanadi.
  static let activityPrefix = "parvoz."

  /// Har kuni 00:00 da holatni qayta hisoblash — hafta kuni almashganda
  /// (yarim tundan o'tuvchi oynalar) ilova yopiq bo'lsa ham to'g'ri bo'lsin.
  static let midnightTick = "parvoz.tick.midnight"

  struct Window: Codable, Equatable {
    /// 0...1439 — kun boshidan daqiqalar.
    let startMinute: Int
    let endMinute: Int
    /// ISO hafta kunlari: 1 = dushanba ... 7 = yakshanba.
    let weekdays: [Int]

    var key: WindowKey { WindowKey(startMinute: startMinute, endMinute: endMinute) }

    /// Davomiylik daqiqada (yarim tundan o'tuvchi oynalar ham).
    var durationMinutes: Int { (endMinute - startMinute + 1440) % 1440 }
  }

  /// DeviceActivity jadvali nomi — bir xil vaqtli oynalar bitta jadvalni
  /// bo'lishadi (hafta kuni `isBlocking`da tekshiriladi).
  struct WindowKey: Hashable {
    static let prefix = "parvoz.window."

    let startMinute: Int
    let endMinute: Int

    init(startMinute: Int, endMinute: Int) {
      self.startMinute = startMinute
      self.endMinute = endMinute
    }

    init?(activityName: String) {
      guard activityName.hasPrefix(Self.prefix) else { return nil }
      let parts = activityName.dropFirst(Self.prefix.count).split(separator: "-")
      guard parts.count == 2, let start = Int(parts[0]), let end = Int(parts[1]) else { return nil }
      self.init(startMinute: start, endMinute: end)
    }

    var activityName: String { "\(Self.prefix)\(startMinute)-\(endMinute)" }
  }

  var blockAll: Bool
  var windows: [Window]
  /// Tanlangan ilovalarga kunlik limit (daqiqa); `nil` — limit yo'q.
  /// Optional — eski saqlangan siyosat ham o'qiladi.
  var dailyLimitMinutes: Int?
  /// Ota-ona "O'chirishdan himoya"ni yoqqan — ilovalarni o'chirish taqiq.
  var denyAppRemoval: Bool?

  static let none = ParvozShieldPolicy(
    blockAll: false,
    windows: [],
    dailyLimitMinutes: nil,
    denyAppRemoval: nil
  )

  func isBlocking(
    at date: Date,
    started: WindowKey? = nil,
    ended: WindowKey? = nil,
    calendar: Calendar = .autoupdatingCurrent
  ) -> Bool {
    if blockAll { return true }
    let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
    guard let weekday = parts.weekday, let hour = parts.hour, let minute = parts.minute else {
      return false
    }
    // Calendar: 1 = yakshanba ... 7 = shanba → ISO: 1 = dushanba ... 7 = yakshanba.
    let isoWeekday = (weekday + 5) % 7 + 1
    let nowMinute = hour * 60 + minute
    return windows.contains { window in
      if window.key == ended { return false }
      guard window.weekdays.contains(isoWeekday) else { return false }
      if window.key == started { return true }
      return Self.isInWindow(nowMinute, window.startMinute, window.endMinute)
    }
  }

  /// Yarim tundan o'tuvchi oynalar ham (22:00–06:00) qo'llab-quvvatlanadi.
  static func isInWindow(_ now: Int, _ start: Int, _ end: Int) -> Bool {
    if start == end { return false }
    if start < end { return now >= start && now < end }
    return now >= start || now < end
  }
}

/// Bloklash ekrani va eslatmalar tili — ilovada tanlangan til (uz/ru/en).
enum ParvozShieldLanguage {
  case uz, ru, en

  init(code: String) {
    switch code.prefix(2).lowercased() {
    case "ru": self = .ru
    case "en": self = .en
    default: self = .uz
    }
  }

  func pick(uz: String, ru: String, en: String) -> String {
    switch self {
    case .uz: return uz
    case .ru: return ru
    case .en: return en
    }
  }
}
