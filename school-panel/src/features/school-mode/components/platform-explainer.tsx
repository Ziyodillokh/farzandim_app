'use client';

import { Apple, EyeOff, Smartphone } from 'lucide-react';

import { SectionCard } from '@/components/common/section-card';
import { useI18n } from '@/i18n';

/** Android va iOS cheklov mexanizmlari farqi (TZ 4.2 eslatmasi). */
export function PlatformExplainer() {
  const { t } = useI18n();
  const items = [
    { icon: Smartphone, title: t('schoolMode.policies.platforms.android'), body: t('schoolMode.policies.platforms.androidBody'), tone: 'bg-success/10 text-success' },
    { icon: Apple, title: t('schoolMode.policies.platforms.ios'), body: t('schoolMode.policies.platforms.iosBody'), tone: 'bg-foreground/10 text-foreground' },
  ];
  return (
    <SectionCard title={t('schoolMode.policies.platforms.title')}>
      <div className="grid gap-3 md:grid-cols-2">
        {items.map(({ icon: Icon, title, body, tone }) => (
          <div key={title} className="flex gap-3 rounded-xl border bg-muted/30 p-4">
            <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${tone}`}>
              <Icon className="h-5 w-5" aria-hidden />
            </span>
            <div>
              <p className="text-sm font-semibold">{title}</p>
              <p className="mt-1 text-sm text-muted-foreground">{body}</p>
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
