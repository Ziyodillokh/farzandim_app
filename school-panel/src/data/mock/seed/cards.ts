import type { Student } from '@/data/contracts';
import { cardNumberFrom } from '@/lib/card-number';
import { hashString } from '@/lib/rng';
import type { MockCard } from '../tables';

/** Har shunchanchi o'quvchining kartasi demo'da «yo'qolgan». */
const LOST_EVERY = 50;
/** Demo raqamlar: 900 mln bilan o'zaro tub qadam — takrorlanmaydi, tasodifiydek ko'rinadi. */
const DEMO_NUMBER_STEP = 829_348_951;

/** Demo: har bir o'quvchiga NFC karta (UID — o'quvchi ID xeshidan, oddiy NTAG). */
export function buildCards(students: readonly Student[]): MockCard[] {
  return students
    .filter((s) => !s.archived)
    .map((s, i) => {
      const part = (salt: string) => hashString(`card-${salt}-${s.id}`).toString(16).padStart(8, '0');
      const lost = i % LOST_EVERY === LOST_EVERY - 1;
      return {
        id: `card-${s.id}`,
        number: cardNumberFrom(100_000_000 + (((i + 1) * DEMO_NUMBER_STEP) % 900_000_000)),
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
