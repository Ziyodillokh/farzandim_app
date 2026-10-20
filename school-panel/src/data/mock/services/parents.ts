import { roleHas } from '@/auth/permissions';
import { ServiceError } from '@/data/contracts';
import { allowedClassIds, currentActor, latency } from '../context';
import { getTables } from '../db';
import { type ParentLinkSummary, parentLinkSummary } from '../parent-links';

/** Ota-onalar ulanishi bo'yicha yagona ko'rsatkichlar (o'quvchilar va ota-onalar ulushi). */
export const parentsService = {
  /** `guardians.link` yoki `students.view` — foydalanuvchi doirasidagi sinflar bo'yicha. */
  async linkSummary(): Promise<ParentLinkSummary> {
    await latency(40, 120);
    const actor = currentActor();
    if (!roleHas(actor.role, 'guardians.link') && !roleHas(actor.role, 'students.view')) {
      throw new ServiceError('FORBIDDEN', 'guardians.link');
    }
    return parentLinkSummary(getTables(), allowedClassIds(actor));
  },
};
