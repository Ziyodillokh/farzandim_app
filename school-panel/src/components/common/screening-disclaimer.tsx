import { Info } from 'lucide-react';

import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** "Skrining, tashxis emas" izohi — psixologik natijalar ko'rsatiladigan har joyda. */
export function ScreeningDisclaimer({ variant = 'inline', withIq = false, className }: { variant?: 'inline' | 'banner'; withIq?: boolean; className?: string }) {
  const { t } = useI18n();
  if (variant === 'inline') {
    return (
      <p className={cn('flex items-start gap-1.5 text-xs text-muted-foreground', className)}>
        <Info className="mt-0.5 h-3.5 w-3.5 shrink-0" />
        <span>
          <span className="font-semibold">{t('common.screening.title')}.</span> {withIq ? t('common.screening.notIq') : t('common.screening.text')}
        </span>
      </p>
    );
  }
  return (
    <div className={cn('flex items-start gap-3 rounded-2xl bg-primary/[0.05] p-4 text-sm ring-1 ring-inset ring-primary/15 dark:bg-white/[0.03]', className)}>
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
        <Info className="h-4 w-4" />
      </span>
      <div>
        <p className="font-semibold">{t('common.screening.title')}</p>
        <p className="mt-0.5 text-muted-foreground">{t('common.screening.text')}</p>
        {withIq && <p className="mt-1 text-xs text-muted-foreground">{t('common.screening.notIq')}</p>}
      </div>
    </div>
  );
}
