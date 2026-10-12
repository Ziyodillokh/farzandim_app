'use client';

import { Info, Layers, ScrollText } from 'lucide-react';
import type { ReactNode } from 'react';

import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import type { PsychTestDetail } from '@/data/mock/services/assessments';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { gradesLabel } from '../../lib/labels';

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className={cn(TILE, 'px-3.5 py-3')}>
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 text-sm font-semibold">{children}</p>
    </div>
  );
}

export function ReadOnlyNote({ test }: { test: PsychTestDetail }) {
  const { t } = useI18n();
  if (!test.readOnly) return null;
  const key = test.source === 'TEMPLATE' ? 'readOnlyTemplate' : test.source === 'EXTERNAL' ? 'readOnlyExternal' : 'readOnlyArchived';
  return (
    <p className="flex items-start gap-2 rounded-xl bg-primary/[0.05] p-3 text-sm text-muted-foreground ring-1 ring-inset ring-primary/15 dark:bg-white/[0.03]">
      <Info className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
      {t(`assessments.view.${key}`)}
    </p>
  );
}

export function OverviewPanel({ test }: { test: PsychTestDetail }) {
  const { t, tc, locale, formatDate } = useI18n();
  const text = (value: string) => value || <span className="text-muted-foreground">{t('assessments.overview.noText')}</span>;

  return (
    <div className="grid items-start gap-6 lg:grid-cols-3">
      <SectionCard icon={<ScrollText />} title={t('assessments.overview.about')} className="lg:col-span-2" bodyClassName="space-y-5 p-5">
        <ReadOnlyNote test={test} />
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          <Fact label={t('assessments.overview.facts.kind')}>{t(`enums.psychKind.${test.kind}`)}</Fact>
          <Fact label={t('assessments.overview.facts.grades')}>{gradesLabel(t, test.grades)}</Fact>
          <Fact label={t('assessments.overview.facts.items')}>{tc('assessments.itemsCount', test.itemCount)}</Fact>
          <Fact label={t('assessments.overview.facts.time')}>{test.timeLimitMin ? t('assessments.minutes', { count: test.timeLimitMin }) : t('assessments.noLimit')}</Fact>
          <Fact label={t('assessments.overview.facts.source')}>{t(`enums.psychSource.${test.source}`)}</Fact>
          <Fact label={t('assessments.overview.facts.updated')}>{formatDate(test.updatedAt, 'd MMM yyyy')}</Fact>
        </div>
        <div>
          <h3 className="text-sm font-semibold">{t('assessments.overview.description')}</h3>
          <p className="mt-1 text-sm leading-relaxed">{text(test.description[locale])}</p>
        </div>
        <div>
          <h3 className="text-sm font-semibold">{t('assessments.overview.instructions')}</h3>
          <p className={cn(TILE, 'mt-2 p-3.5 text-sm leading-relaxed')}>{text(test.instructions[locale])}</p>
        </div>
      </SectionCard>

      <SectionCard icon={<Layers />} title={t('assessments.overview.scales')} description={t('assessments.overview.scalesHint')}>
        <ul className="space-y-2">
          {test.scales.map((s) => (
            <li key={s.key} className={cn(TILE, 'p-3')}>
              <div className="flex items-center justify-between gap-2">
                <span className="font-medium">{s.label[locale]}</span>
                <code className="rounded bg-muted px-1.5 py-0.5 text-2xs text-muted-foreground">{s.key}</code>
              </div>
              <div className="mt-2 flex flex-wrap gap-1.5">
                <Badge variant="secondary" size="sm">
                  {s.domain ? t(`enums.devDomain.${s.domain}`) : t('assessments.overview.noDomain')}
                </Badge>
                <Badge variant={s.polarity === 'HIGHER_CONCERN' ? 'warning' : 'info'} size="sm">
                  {t(`assessments.overview.polarity.${s.polarity}`)}
                </Badge>
                <Badge variant="outline" size="sm">
                  {t(`assessments.overview.display.${s.display}`)}
                </Badge>
              </div>
            </li>
          ))}
        </ul>
      </SectionCard>
    </div>
  );
}
