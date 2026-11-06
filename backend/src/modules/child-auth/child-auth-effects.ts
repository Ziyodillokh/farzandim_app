// Javobdan KEYIN fonda bajariladigan ta'sirlar (push, xodim bildirishnomasi, audit): xatosi chaqiruvchiga o'tmaydi,
// jarayon yopilishi / testlar tugashini `drain()` kutadi. Javob vaqti ta'sir bor-yo'qligiga bog'liq bo'lmaydi.

import { Injectable, Logger } from '@nestjs/common';
import { errorLabel } from '../../common/notification-prefs/error-label';

@Injectable()
export class ChildAuthEffects {
  private readonly logger = new Logger(ChildAuthEffects.name);
  private readonly pending = new Set<Promise<void>>();

  /** `work` rad etilsa xato faqat logga (turi bilan, shaxsiy ma'lumotsiz) yoziladi. */
  track(work: Promise<void>, label = 'ta\'sir'): void {
    const tracked: Promise<void> = work
      .catch((err) => this.logger.warn(`${label} bajarilmadi: ${errorLabel(err)}`))
      .finally(() => this.pending.delete(tracked));
    this.pending.add(tracked);
  }

  /** Fonda ketayotgan ta'sirlar tugashini kutadi. */
  async drain(): Promise<void> {
    await Promise.allSettled([...this.pending]);
  }
}
