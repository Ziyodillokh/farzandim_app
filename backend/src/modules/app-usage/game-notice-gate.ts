// «O'yin ochildi» push'lari uchun darvoza: bir bola + o'yin bo'yicha
// DEDUP_MS ichida faqat bitta push, oflayn navbatdan MAX_AGE_MS dan kech
// kelgan xabar esa umuman yuborilmaydi (ota-ona soatlab eski hodisani
// "hozir o'ynayapti" deb ko'rmasin). Holat jarayon xotirasida — qayta
// ishga tushirilgandan keyin eng ko'pi bilan bitta ortiqcha push.

export const GAME_NOTICE_DEDUP_MS = 5 * 60_000;
export const GAME_NOTICE_MAX_AGE_MS = 10 * 60_000;
/** Xotira chegarasi: shundan oshsa eskirgan yozuvlar tozalanadi. */
const MAX_ENTRIES = 5_000;

export class GameNoticeGate {
  private readonly lastNotifiedAt = new Map<string, number>();

  /** Push yuborilsinmi; ruxsat berilsa vaqt eslab qolinadi. */
  shouldNotify(childId: string, packageName: string, openedAt?: string, now: number = Date.now()): boolean {
    if (openedAt) {
      const at = Date.parse(openedAt);
      if (Number.isFinite(at) && now - at > GAME_NOTICE_MAX_AGE_MS) return false;
    }
    const key = `${childId}:${packageName}`;
    const last = this.lastNotifiedAt.get(key);
    if (last !== undefined && now - last < GAME_NOTICE_DEDUP_MS) return false;
    if (this.lastNotifiedAt.size >= MAX_ENTRIES) this.prune(now);
    this.lastNotifiedAt.set(key, now);
    return true;
  }

  private prune(now: number): void {
    for (const [key, at] of this.lastNotifiedAt) {
      if (now - at >= GAME_NOTICE_DEDUP_MS) this.lastNotifiedAt.delete(key);
    }
  }
}
