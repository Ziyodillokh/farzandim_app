'use client';

import { BookOpen, CalendarCheck } from 'lucide-react';
import type { ReactNode } from 'react';

import type { StudentDevProfile } from '@/data/contracts';
import { ICON_CHIP, TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

function Tile({ icon, title, value, details }: { icon: ReactNode; title: string; value: ReactNode; details: string[] }) {
  return (
    <li className={cn(TILE, 'flex items-start gap-3 px-4 py-3.5')}>
      <span className={cn(ICON_CHIP, 'h-9 w-9 bg-primary/10 text-primary ring-primary/15 [&_svg]:size-4')}>{icon}</span>
      <div className="min-w-0">
        <p className="text-xs text-muted-foreground">{title}</p>
        <p className="font-display text-xl font-semibold tabular-nums">{value}</p>
        <p className="mt-0.5 text-xs text-muted-foreground">{details.join(' · ')}</p>
      </div>
    </li>
  );
}

/** Kontekst: davomat (faqat sinf rahbari) va sinfning o'quv faolligi. */
export function ContextCard({ context }: { context: StudentDevProfile['context'] }) {
  const { t } = useI18n();
  const a = context.attendance30;
  const l = context.classLearning;
  return (
    <ul className="grid gap-3">
      {a && (
        <Tile
          icon={<CalendarCheck />}
          title={t('development.profile.attendance30')}
          value={a.rate === null ? '—' : `${a.rate}%`}
          details={[t('development.profile.late', { n: a.late }), t('development.profile.absent', { n: a.absent })]}
        />
      )}
      {l && (
        <Tile
          icon={<BookOpen />}
          title={t('development.profile.classLearning')}
          value={`${l.avgScore}`}
          details={[t('development.profile.activeRate', { rate: l.activeRate }), t('development.profile.avgScore', { score: l.avgScore })]}
        />
      )}
    </ul>
  );
}
