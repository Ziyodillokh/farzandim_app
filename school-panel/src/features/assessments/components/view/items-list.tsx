'use client';

import { CheckCircle2, Eye, ListChecks } from 'lucide-react';

import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import type { PsychItem } from '@/data/contracts';
import type { PsychTestDetail } from '@/data/mock/services/assessments';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { ReadOnlyNote } from './overview-panel';

function ItemBody({ item, scaleLabel }: { item: PsychItem; scaleLabel: (key: string) => string }) {
  const { t, locale } = useI18n();
  if (item.type === 'LIKERT') {
    return (
      <div className="mt-2 flex flex-wrap gap-1.5">
        <Badge variant="secondary" size="sm">{scaleLabel(item.scale)}</Badge>
        {item.reverse && <Badge variant="warning" size="sm">{t('assessments.items.reverse')}</Badge>}
      </div>
    );
  }
  return (
    <>
      {item.type === 'SINGLE' && item.stimulus && (
        <div className="mt-2 rounded-lg bg-primary/[0.06] px-3 py-2 text-sm ring-1 ring-inset ring-primary/15">
          <p className="flex items-center gap-1.5 text-2xs font-semibold uppercase tracking-wide text-primary">
            <Eye className="h-3 w-3" />
            {t('assessments.items.stimulus', { sec: item.stimulus.showSec })}
          </p>
          <p className="mt-1 font-medium">{item.stimulus.text[locale]}</p>
        </div>
      )}
      <ul className="mt-2 grid gap-1.5 sm:grid-cols-2">
        {item.options.map((o) => {
          const correct = item.type === 'SINGLE' && o.key === item.correct;
          return (
            <li
              key={o.key}
              className={cn('flex items-center gap-2 rounded-lg px-2.5 py-1.5 text-sm ring-1 ring-inset ring-border/60', correct && 'bg-success/10 font-medium ring-success/30')}
            >
              <span className="font-mono text-xs text-muted-foreground">{o.key}</span>
              <span className="flex-1">{o.text[locale]}</span>
              {correct && <CheckCircle2 className="h-4 w-4 text-success" aria-label={t('assessments.items.correct')} />}
              {item.type === 'MULTI' && 'scale' in o && <Badge variant="outline" size="sm">{scaleLabel(o.scale)}</Badge>}
            </li>
          );
        })}
      </ul>
    </>
  );
}

/** Savollar — faqat o'qish (shablon, tashqi yoki arxivdagi test). */
export function ItemsList({ test }: { test: PsychTestDetail }) {
  const { t, tc, locale } = useI18n();
  const scaleLabel = (key: string) => test.scales.find((s) => s.key === key)?.label[locale] ?? key;
  return (
    <SectionCard icon={<ListChecks />} title={t('assessments.view.tabs.items')} description={tc('assessments.itemsCount', test.items.length)} bodyClassName="space-y-4 p-5">
      <ReadOnlyNote test={test} />
      {test.items.length === 0 ? (
        <EmptyState icon={<ListChecks />} title={t('assessments.items.empty')} description={t('assessments.items.emptyHint')} />
      ) : (
        <ol className="space-y-3">
          {test.items.map((item, i) => (
            <li key={item.id} className={cn(TILE, 'p-4')}>
              <div className="flex items-start gap-3">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-xs font-semibold tabular-nums text-primary">{i + 1}</span>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <p className="font-medium leading-snug">{item.text[locale]}</p>
                    <Badge variant="outline" size="sm">{t(`assessments.items.type.${item.type}`)}</Badge>
                  </div>
                  <ItemBody item={item} scaleLabel={scaleLabel} />
                </div>
              </div>
            </li>
          ))}
        </ol>
      )}
    </SectionCard>
  );
}
