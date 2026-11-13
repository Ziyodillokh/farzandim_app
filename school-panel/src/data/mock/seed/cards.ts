import type { Student } from '@/data/contracts';
import { hashString } from '@/lib/rng';
import type { MockCard } from '../tables';

/** Har shunchanchi o'quvchining kartasi demo'da «yo'qolgan». */
const LOST_EVERY = 50;

/** Demo: har bir o'quvchiga NFC karta (UID — o'quvchi ID xeshidan, oddiy NTAG). */
export function buildCards(students: readonly Student[]): MockCard[] {
  return students
    .filter((s) => !s.archived)
    .map((s, i) => {
      const part = (salt: string) => hashString(`card-${salt}-${s.id}`).toString(16).padStart(8, '0');
      const lost = i % LOST_EVERY === LOST_EVERY - 1;
      return {
        id: `card-${s.id}`,
        number: `K-${String(i + 1).padStart(6, '0')}`,
        uid: `04${part('a')}${part('b')}`.slice(0, 14).toUpperCase(),
        kind: 'UID',
        status: lost ? 'LOST' : 'ACTIVE',
        studentId: s.id,
        issuedAt: `${s.enrolledAt}T08:00:00`,
        lastTapAt: null,
        blockedAt: lost ? `${s.enrolledAt}T08:00:00` : null,
        blockedReason: lost ? 'LOST' : null,
      };
    });
}
