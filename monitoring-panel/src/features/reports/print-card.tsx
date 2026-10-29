'use client';

import { FileText, Landmark, MapPin, Printer } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

import { useCan } from '@/auth/use-session';
import { Section } from '@/components/common/section';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectSeparator, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { Scope } from '@/data/contracts';
import { REGIONS, regionName } from '@/data/reference/regions';
import { useI18n } from '@/i18n';

export const NATIONAL_REPORT_ID = 'UZ';
const PRINT_SECTIONS = ['s1', 's2Regions', 's3', 's4', 's5', 's6', 's7', 's8'] as const;

/** Chop etiladigan hisobot: doirani tanlash va hujjat ko'rinishini ochish. */
export function PrintCard({ scope }: { scope: Scope }) {
  const { t, locale } = useI18n();
  const can = useCan();
  const national = can('regions.view');
  const [target, setTarget] = useState<string>(scope.kind === 'REGION' ? scope.regionId : NATIONAL_REPORT_ID);
  const value = national ? target : scope.kind === 'REGION' ? scope.regionId : NATIONAL_REPORT_ID;

  return (
    <Section id="print" icon={<FileText />} title={t('reports.printTitle')} subtitle={t('reports.printSub')}>
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
        <div className="space-y-4">
          <div>
            <p className="mb-1.5 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('reports.printScope')}</p>
            {national ? (
              <Select value={value} onValueChange={setTarget}>
                <SelectTrigger aria-label={t('reports.printScope')} className="h-10 w-full max-w-[320px] gap-2">
                  {value === NATIONAL_REPORT_ID ? <Landmark className="h-4 w-4 text-primary" /> : <MapPin className="h-4 w-4 text-primary" />}
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={NATIONAL_REPORT_ID}>{t('shell.scopeNational')}</SelectItem>
                  <SelectSeparator />
                  {REGIONS.map((r) => (
                    <SelectItem key={r.id} value={r.id}>
                      {locale === 'ru' ? r.nameRu : r.nameUz}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            ) : (
              <p className="inline-flex h-10 items-center gap-2 rounded-xl bg-primary/[0.06] px-3 text-sm font-medium ring-1 ring-inset ring-border/60">
                <MapPin className="h-4 w-4 text-primary" />
                {scope.kind === 'REGION' ? regionName(scope.regionId, locale) : t('shell.scopeNational')}
              </p>
            )}
          </div>
          <Button asChild className="rounded-xl">
            <Link href={`/reports/print?id=${value}`}>
              <Printer />
              {t('reports.printOpen')}
            </Link>
          </Button>
          <p className="max-w-md text-xs leading-relaxed text-muted-foreground">{t('reports.printHow')}</p>
        </div>
        <div>
          <p className="mb-2 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('reports.printIncludes')}</p>
          <ol className="grid gap-1.5 sm:grid-cols-2">
            {PRINT_SECTIONS.map((s, i) => (
              <li key={s} className="flex items-center gap-2.5 rounded-xl bg-primary/[0.04] px-3 py-2 text-[0.8rem] ring-1 ring-inset ring-border/50 dark:bg-white/[0.03]">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-lg bg-primary/12 font-display text-[0.7rem] font-semibold text-primary">{i + 1}</span>
                {t(`reports.print.${s}`)}
              </li>
            ))}
          </ol>
        </div>
      </div>
    </Section>
  );
}
