import ManagedSettings
import UserNotifications

/// Bloklash ekrani tugmalari.
///   • Asosiy ("Yopish") — cheklangan ilovani yopadi.
///   • Ikkinchi ("Qo'shimcha vaqt so'rash") — so'rov belgisini App Group'ga
///     yozadi va eslatma ko'rsatadi; bola uni bosganda Parvoz ochiladi va
///     so'rovni (necha daqiqa, sabab) ota-onaga yuboradi. Kengaytmada tarmoq
///     va avtorizatsiya token'i yo'q, ilova nomi esa serverga yuborilmaydi.
final class ParvozShieldAction: ShieldActionDelegate {
  private static let notificationId = "parvoz.unlock.request"

  override func handle(
    action: ShieldAction,
    for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    respond(to: action, completionHandler: completionHandler)
  }

  override func handle(
    action: ShieldAction,
    for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    respond(to: action, completionHandler: completionHandler)
  }

  override func handle(
    action: ShieldAction,
    for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    respond(to: action, completionHandler: completionHandler)
  }

  private func respond(
    to action: ShieldAction,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    switch action {
    case .primaryButtonPressed:
      completionHandler(.close)
    case .secondaryButtonPressed:
      ParvozShield.markUnlockRequested()
      Self.postRequestNotification { completionHandler(.close) }
    @unknown default:
      completionHandler(.close)
    }
  }

  private static func postRequestNotification(then done: @escaping () -> Void) {
    let lang = ParvozShield.language()
    let content = UNMutableNotificationContent()
    content.title = lang.pick(uz: "Qo'shimcha vaqt so'rash", ru: "Попросить ещё время", en: "Ask for more time")
    content.body = lang.pick(
      uz: "Bosing — Parvoz ochiladi va so'rovingiz ota-onangizga yuboriladi.",
      ru: "Нажмите — откроется Parvoz, и запрос уйдёт родителям.",
      en: "Tap to open Parvoz and send the request to your parents."
    )
    content.sound = .default
    let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { _ in done() }
  }
}
