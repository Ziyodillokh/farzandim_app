'use client';

import { BookOpenCheck, Brain, Compass, Download, HeartHandshake, Loader2, School, Table2, type LucideIcon } from 'lucide-react';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import type { Filters, Scope } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { downloadCsv } from '@/lib/csv';
import { type DatasetKey, useDatasetBuilder } from './datasets';

const ICONS: Record<DatasetKey, LucideIcon> = {
  indicators: Table2,
  mastery: BookOpenCheck,
  problems: HeartHandshake,
  iq: Brain,
  interests: Compass,
  schools: School,
};

/** Bitta CSV to'plami: tavsif va yuklab olish (bosilganda hisoblanadi). */
export function DatasetCard({ dataset, scope, filters, rowsLabel }: { dataset: DatasetKey; scope: Scope; filters: Filters; rowsLabel: string }) {
  const { t } = useI18n();
  const build = useDatasetBuilder();
  const [state, setState] = useState<'idle' | 'busy' | 'error'>('idle');
  const Icon = ICONS[dataset];

  const onDownload = async () => {
    setState('busy');
    try {
      const { filename, rows, columns } = await build(dataset, scope, filters);
      downloadCsv(filename, rows, columns);
      setState('idle');
    } catch {
      setState('error');
    }
  };

  return (
    <div className="flex flex-col rounded-2xl bg-primary/[0.04] p-4 ring-1 ring-inset ring-border/60 transition-colors hover:ring-primary/35 dark:bg-white/[0.03]">
      <div className="flex items-start gap-3">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15">
          <Icon className="h-[18px] w-[18px]" />
        </span>
        <div className="min-w-0">
          <h3 className="text-[0.92rem] font-semibold leading-snug">{t(`reports.datasets.${dataset}.title`)}</h3>
          <p className="mt-0.5 text-[0.72rem] font-medium text-muted-foreground">{rowsLabel}</p>
        </div>
      </div>
      <p className="mt-3 flex-1 text-[0.8rem] leading-relaxed text-muted-foreground">{t(`reports.datasets.${dataset}.description`)}</p>
      <div className="mt-4 flex items-center gap-3">
        <Button size="sm" onClick={onDownload} disabled={state === 'busy'} className="rounded-xl">
          {state === 'busy' ? <Loader2 className="animate-spin" /> : <Download />}
          {state === 'busy' ? t('reports.preparing') : t('reports.download')}
        </Button>
        {state === 'error' && (
          <span role="alert" className="text-xs text-amber-600 dark:text-amber-400">
            {t('reports.failed')}
          </span>
        )}
      </div>
    </div>
  );
}
