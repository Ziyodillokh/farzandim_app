'use client';

import { Lock, Smartphone } from 'lucide-react';

import { PhoneMockup } from '@/components/common/phone-mockup';
import { SectionCard } from '@/components/common/section-card';
import type { PsychTestDetail } from '@/data/mock/services/assessments';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { PhoneRunner } from './phone-runner';

/** "Parvoz ilovasida" — o'quvchi testni telefonda qanday ko'radi (javoblar saqlanmaydi). */
export function PreviewPanel({ test }: { test: PsychTestDetail }) {
  const { t, tc, locale } = useI18n();
  return (
    <div className="grid items-start gap-6 lg:grid-cols-[1fr_auto]">
      <SectionCard icon={<Smartphone />} title={t('assessments.preview.title')} description={t('assessments.preview.hint')} bodyClassName="space-y-3 p-5">
        <div className={cn(TILE, 'p-4')}>
          <p className="font-semibold">{test.title[locale]}</p>
          <p className="mt-1 text-sm text-muted-foreground">
            {tc('assessments.itemsCount', test.itemCount)}
            {test.timeLimitMin ? ` · ${t('assessments.minutes', { count: test.timeLimitMin })}` : ''}
          </p>
        </div>
        {test.instructions[locale] && <p className={cn(TILE, 'p-4 text-sm leading-relaxed')}>{test.instructions[locale]}</p>}
        <p className="flex items-center gap-2 text-xs text-muted-foreground">
          <Lock className="h-3.5 w-3.5" />
          {t('assessments.preview.demoNote')}
        </p>
      </SectionCard>
      <PhoneMockup className="lg:sticky lg:top-24">
        <PhoneRunner key={`${test.id}:${test.version}`} test={test} />
      </PhoneMockup>
    </div>
  );
}
