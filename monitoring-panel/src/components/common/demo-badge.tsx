'use client';

import { FlaskConical } from 'lucide-react';

import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** "Demo ma'lumotlar" belgisi — har sahifada ko'rinadi (haqiqiy natija bilan adashtirilmasin). */
export function DemoBadge({ className, tone = 'auto', compact = false }: { className?: string; tone?: 'auto' | 'onDark'; compact?: boolean }) {
  const { t } = useI18n();
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span
          tabIndex={0}
          className={cn(
            'inline-flex h-7 shrink-0 cursor-help items-center gap-1.5 rounded-full px-2.5 text-[0.7rem] font-semibold uppercase tracking-[0.08em] ring-1 ring-inset',
            tone === 'onDark'
              ? 'bg-amber-400/10 text-amber-200 ring-amber-300/30'
              : 'bg-warning/10 text-warning ring-warning/30',
            className,
          )}
        >
          <FlaskConical className="h-3.5 w-3.5" />
          {compact ? t('common.demoShort') : t('common.demoBadge')}
        </span>
      </TooltipTrigger>
      <TooltipContent className="max-w-xs text-xs leading-relaxed">{t('common.demoHint')}</TooltipContent>
    </Tooltip>
  );
}
