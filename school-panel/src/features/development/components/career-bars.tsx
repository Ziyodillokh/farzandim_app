'use client';

import type { StudentDevProfile } from '@/data/contracts';
import { type TKey, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const CODES = ['R', 'I', 'A', 'S', 'E', 'C'] as const;
const MAX = 6;
const codeKey = (c: (typeof CODES)[number]): TKey => `development.profile.careerCodes.${c}`;

/** Kasbiy qiziqishlar (8-sinfdan): 6 yo'nalish, kuchli uchtasi ajratilgan. */
export function CareerBars({ career }: { career: NonNullable<StudentDevProfile['career']> }) {
  const { t } = useI18n();
  const top = new Set(career.topCodes.split(''));
  return (
    <ul className="space-y-2.5 animate-fade-in">
      {CODES.map((c) => {
        const v = career.raw[c] ?? 0;
        const strong = top.has(c);
        return (
          <li key={c} className="flex items-center gap-3 text-sm">
            <span className={cn('w-36 shrink-0 truncate', strong ? 'font-semibold' : 'text-muted-foreground')}>{t(codeKey(c))}</span>
            <span className="relative h-2.5 flex-1 overflow-hidden rounded-full bg-primary/[0.07]">
              <span className={cn('absolute inset-y-0 left-0 rounded-full', strong ? 'bg-primary' : 'bg-sky-400/60')} style={{ width: `${(v / MAX) * 100}%` }} />
            </span>
            <span className="w-8 text-right text-xs font-semibold tabular-nums">{v}/{MAX}</span>
          </li>
        );
      })}
    </ul>
  );
}

export function careerTitleCodes(career: NonNullable<StudentDevProfile['career']>, t: (key: TKey) => string): string {
  return career.topCodes
    .split('')
    .filter((c): c is (typeof CODES)[number] => (CODES as readonly string[]).includes(c))
    .map((c) => t(codeKey(c)))
    .join(', ');
}
