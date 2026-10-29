'use client';

import type { ReactNode } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { Card } from '@/components/ui/card';
import { K_MIN } from '@/data/mock/model/engine';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** Bo'lim ichidagi kichik sarlavha (dashboard uslubida). */
export function SubHeading({ children, aside, className }: { children: ReactNode; aside?: ReactNode; className?: string }) {
  return (
    <div className={cn('mb-2.5 flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1', className)}>
      <p className="text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{children}</p>
      {aside && <div className="text-[0.72rem] text-muted-foreground">{aside}</div>}
    </div>
  );
}

/** Bo'lim ichidagi yumshoq fonli blok. */
export function Inset({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('rounded-xl bg-primary/[0.05] p-3.5 ring-1 ring-inset ring-border/50 dark:bg-white/[0.03]', className)}>{children}</div>;
}

/** Izoh matni (grafik ostida). */
export function Note({ children, className }: { children: ReactNode; className?: string }) {
  return <p className={cn('text-[0.72rem] leading-relaxed text-muted-foreground', className)}>{children}</p>;
}

/** Sahifa ma'lumotini yuklashda xatolik — qayta urinish tugmasi bilan. */
export function QueryError({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  return (
    <Card>
      <ErrorState error={error} onRetry={onRetry} />
    </Card>
  );
}

/** Sahifa oxiridagi izohlar: maxfiylik, hududlar farqi va manbalar. */
export function LearningFooter({ children }: { children?: ReactNode }) {
  const { t } = useI18n();
  return (
    <footer className="space-y-1.5 rounded-2xl bg-primary/[0.04] p-4 text-[0.72rem] text-muted-foreground ring-1 ring-inset ring-border/50 dark:bg-white/[0.02]">
      {children}
      <p>
        <b className="text-foreground">{t('common.privacy.title')}.</b> {t('common.privacy.text', { k: K_MIN })}
      </p>
      <p>{t('common.screening.regionsNote')}</p>
      <p>{t('dashboard.sourcesNote')}</p>
    </footer>
  );
}
