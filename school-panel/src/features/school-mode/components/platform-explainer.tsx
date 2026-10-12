'use client';

import { Apple, EyeOff, Smartphone, TabletSmartphone } from 'lucide-react';

import { SectionCard } from '@/components/common/section-card';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { TILE } from '../lib';

/** Android va iOS cheklov mexanizmlari farqi (TZ 4.2 eslatmasi). */
export function PlatformExplainer() {
  const { t } = useI18n();
  const items = [
    {
      icon: Smartphone,
      title: t('schoolMode.policies.platforms.android'),
      body: t('schoolMode.policies.platforms.androidBody'),
      tone: 'bg-sky-500/10 text-sky-600 ring-sky-500/20 dark:text-sky-400',
    },
    {
      icon: Apple,
      title: t('schoolMode.policies.platforms.ios'),
      body: t('schoolMode.policies.platforms.iosBody'),
      tone: 'bg-primary/10 text-primary ring-primary/20',
    },
  ];
  return (
    <SectionCard icon={<TabletSmartphone />} title={t('schoolMode.policies.platforms.title')}>
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-1">
        {items.map(({ icon: Icon, title, body, tone }) => (
          <div key={title} className={cn('flex gap-3.5 p-4', TILE)}>
            <span className={cn('flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ring-1 ring-inset', tone)}>
              <Icon className="h-5 w-5" aria-hidden />
            </span>
            <div className="min-w-0">
              <p className="text-sm font-semibold">{title}</p>
              <p className="mt-1 text-sm leading-relaxed text-muted-foreground">{body}</p>
            </div>
          </div>
        ))}
      </div>
      <p className="mt-4 flex items-start gap-2 text-xs text-muted-foreground">
        <EyeOff className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden />
        {t('schoolMode.policies.platforms.note')}
      </p>
    </SectionCard>
  );
}
