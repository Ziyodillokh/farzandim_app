import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Cheklangan ilova ochilganda ko'rinadigan Parvoz dizaynidagi ekran.
/// Matn ilovada tanlangan tilda (App Group orqali, `ParvozShield.language`).
/// Izoh cheklov SABABIGA mos: jadval, kunlik limit yoki doimiy cheklov;
/// "vaqt so'rash" bosilgan bo'lsa — so'rov saqlangani va uni Parvoz orqali
/// yuborish kerakligi (eslatmalar o'chiq bo'lsa ham bola biladi).
final class ParvozShieldConfig: ShieldConfigurationDataSource {
  /// Bloklash ekrani izohining sababi.
  private enum Reason {
    case pendingRequest, alwaysOn, dailyLimit, schedule

    static func current(now: Date = Date()) -> Reason {
      if ParvozShield.hasPendingUnlockRequest(now: now) { return .pendingRequest }
      let policy = ParvozShield.loadPolicy()
      if policy.blockAll { return .alwaysOn }
      if policy.dailyLimitMinutes != nil, ParvozShield.isDailyLimitReached(now: now) {
        return .dailyLimit
      }
      if policy.isBlocking(at: now) { return .schedule }
      return .alwaysOn
    }
  }

  private static let background = UIColor(red: 2 / 255, green: 6 / 255, blue: 13 / 255, alpha: 1)
  private static let accent = UIColor(red: 33 / 255, green: 107 / 255, blue: 255 / 255, alpha: 1)
  private static let subtitleColor = UIColor(white: 1, alpha: 0.7)

  override func configuration(shielding application: Application) -> ShieldConfiguration {
    Self.make(appName: application.localizedDisplayName)
  }

  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    Self.make(appName: application.localizedDisplayName)
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    Self.make(appName: webDomain.domain)
  }

  override func configuration(
    shielding webDomain: WebDomain,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    Self.make(appName: webDomain.domain)
  }

  private static func make(appName: String?) -> ShieldConfiguration {
    let lang = ParvozShield.language()
    let title: String
    if let appName, !appName.isEmpty {
      title = lang.pick(
        uz: "\(appName) hozir cheklangan",
        ru: "\(appName) сейчас ограничено",
        en: "\(appName) is restricted now"
      )
    } else {
      title = lang.pick(uz: "Hozir cheklangan", ru: "Сейчас ограничено", en: "Restricted now")
    }
    return ShieldConfiguration(
      backgroundBlurStyle: .systemUltraThinMaterialDark,
      backgroundColor: background,
      icon: UIImage(named: "ShieldIcon"),
      title: ShieldConfiguration.Label(text: title, color: .white),
      subtitle: ShieldConfiguration.Label(
        text: subtitle(for: Reason.current(), lang: lang),
        color: subtitleColor
      ),
      primaryButtonLabel: ShieldConfiguration.Label(
        text: lang.pick(uz: "Yopish", ru: "Закрыть", en: "Close"),
        color: .white
      ),
      primaryButtonBackgroundColor: accent,
      secondaryButtonLabel: ShieldConfiguration.Label(
        text: lang.pick(uz: "Qo'shimcha vaqt so'rash", ru: "Попросить ещё время", en: "Ask for more time"),
        color: accent
      )
    )
  }

  private static func subtitle(for reason: Reason, lang: ParvozShieldLanguage) -> String {
    switch reason {
    case .pendingRequest:
      return lang.pick(
        uz: "So'rov saqlandi. Ota-onangga yuborish uchun Parvoz ilovasini och.",
        ru: "Запрос сохранён. Открой Parvoz, чтобы отправить его родителям.",
        en: "Request saved. Open Parvoz to send it to your parents."
      )
    case .dailyLimit:
      return lang.pick(
        uz: "Bugungi vaqt limiti tugadi — ertaga yana ochiladi. Kerak bo'lsa, qo'shimcha vaqt so'ra.",
        ru: "Лимит времени на сегодня исчерпан — завтра откроется снова. Если нужно, попроси дополнительное время.",
        en: "Today's time limit is used up — it opens again tomorrow. If you need it, ask for more time."
      )
    case .schedule:
      return lang.pick(
        uz: "Ota-onang belgilagan vaqt jadvali bo'yicha. Kerak bo'lsa, qo'shimcha vaqt so'ra.",
        ru: "По расписанию, которое задали родители. Если нужно, попроси дополнительное время.",
        en: "Your parents set this schedule. If you need it, ask for more time."
      )
    case .alwaysOn:
      return lang.pick(
        uz: "Ota-onang bu ilovani cheklab qo'ygan. Kerak bo'lsa, qo'shimcha vaqt so'ra.",
        ru: "Родители ограничили это приложение. Если нужно, попроси дополнительное время.",
        en: "Your parents have restricted this app. If you need it, ask for more time."
      )
    }
  }
}
