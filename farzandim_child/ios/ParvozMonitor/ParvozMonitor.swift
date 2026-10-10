import DeviceActivity
import Foundation

/// Ota-ona jadvali oynasi boshlanganda / tugaganda iOS shu kengaytmani
/// uyg'otadi — ilova yopiq bo'lsa ham cheklov o'z vaqtida yoqiladi/o'chadi.
/// Qaror `ParvozShield` (Shared) da: siyosat + tanlov + joriy vaqt.
final class ParvozMonitor: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    ParvozShield.enforce(started: ParvozShieldPolicy.WindowKey(activityName: activity.rawValue))
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    ParvozShield.enforce(ended: ParvozShieldPolicy.WindowKey(activityName: activity.rawValue))
  }
}
