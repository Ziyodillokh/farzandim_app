import DeviceActivity
import Foundation

/// iOS shu kengaytmani ilova yopiq bo'lsa ham uyg'otadi:
///   • ota-ona jadvali oynasi boshlanganda / tugaganda;
///   • har kuni yarim tunda (hafta kuni almashishi);
///   • ota-ona bergan qo'shimcha vaqt tugaganda yoki shuncha daqiqa
///     foydalanilganda;
///   • tanlangan ilovalarning kunlik limiti tugaganda va yangi kun boshida.
/// Qaror `ParvozShield` (Shared) da: siyosat + tanlov + joriy vaqt.
final class ParvozMonitor: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    if activity.rawValue == ParvozShield.unlockActivity { return }
    if activity.rawValue == ParvozShield.dailyActivity {
      // Yangi kun: "limit tugadi" belgisi yarim tunda o'zi eskiradi. Bu
      // chaqiruv jadval qayta boshlanganda ham keladi — belgi o'chirilmaydi.
      ParvozShield.enforce()
      return
    }
    ParvozShield.enforce(started: ParvozShieldPolicy.WindowKey(activityName: activity.rawValue))
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    if activity.rawValue == ParvozShield.unlockActivity {
      endUnlock()
      return
    }
    ParvozShield.enforce(ended: ParvozShieldPolicy.WindowKey(activityName: activity.rawValue))
  }

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
    if event.rawValue == ParvozShield.unlockLimitEvent {
      endUnlock()
    } else if event.rawValue == ParvozShield.dailyLimitEvent {
      ParvozShield.setDailyLimitReached(true)
      ParvozShield.enforce()
    }
  }

  /// Qo'shimcha vaqt tugadi — cheklov joriy siyosat bo'yicha qaytadi.
  private func endUnlock() {
    try? ParvozShield.setUnlockUntil(nil)
    ParvozShield.enforce()
  }
}
