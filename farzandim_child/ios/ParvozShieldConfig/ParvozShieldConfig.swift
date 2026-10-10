import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Cheklangan ilova ochilganda ko'rinadigan Parvoz dizaynidagi ekran.
/// Matn ilovada tanlangan tilda (App Group orqali, `ParvozShield.language`).
final class ParvozShieldConfig: ShieldConfigurationDataSource {
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
        text: lang.pick(
          uz: "Ota-onang belgilagan vaqt jadvali bo'yicha. Kerak bo'lsa, qo'shimcha vaqt so'ra.",
          ru: "По расписанию, которое задали родители. Если нужно, попроси дополнительное время.",
          en: "Your parents set this schedule. If you need it, ask for more time."
        ),
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
}
