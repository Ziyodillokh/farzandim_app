'use client';

import { ChevronRight, ClipboardCheck, Users } from 'lucide-react';
import Link from 'next/link';
import { useEffect, useState } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { StatCard } from '@/components/common/stat-card';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Skeleton } from '@/components/ui/skeleton';
import type { ClassDevOverview, ClassDevRow, DevDomain } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { TILE_INTERACTIVE } from '@/features/dashboard/lib/tile';
import { cn, percent } from '@/lib/utils';
import { useDevClass, useDevClassOptions, useDevTerms } from '../hooks';
import { DOMAINS, domainKey } from '../lib/domains';
import { BandChip } from './band-chip';
import { DomainAverages } from './domain-averages';
import { TermSelect } from './term-select';

function StudentRow({ row, showAttention, domains }: { row: ClassDevRow; showAttention: boolean; domains: readonly DevDomain[] }) {
  const { t, formatDate } = useI18n();
  return (
    <tr className="border-t border-border/50 align-middle transition-colors hover:bg-primary/[0.03] dark:border-white/[0.06]">
      <th scope="row" className="py-2.5 pl-1 pr-3 text-left font-medium">
        <Link href={`/students/view?id=${row.studentId}&tab=development`} className="group inline-flex items-center gap-1 hover:text-primary">
          <span className="whitespace-nowrap">{row.name}</span>
          <ChevronRight className="h-3.5 w-3.5 opacity-0 transition-opacity group-hover:opacity-100" />
        </Link>
        {showAttention && row.attention && (
          <Badge variant="info" size="sm" className="ml-2 align-middle">
            {t('development.classView.attentionBadge')}
          </Badge>
        )}
      </th>
      <td className="whitespace-nowrap px-2 text-xs tabular-nums text-muted-foreground">
        {row.assessedAt ? formatDate(row.assessedAt, 'd MMM') : t('development.classView.notAssessed')}
      </td>
      {domains.map((d) => {
        const v = row.domains[d];
        return (
          <td key={d} className="px-1.5 py-2">
            <BandChip band={v?.band} index={v?.index} />
          </td>
        );
      })}
    </tr>
  );
}

/** Telefon: jadval o'rniga kartochka (sohalar o'raladi, gorizontal aylantirish yo'q). */
function MobileRow({ row, showAttention, domains }: { row: ClassDevRow; showAttention: boolean; domains: readonly DevDomain[] }) {
  const { t, formatDate } = useI18n();
  return (
    <li>
      <Link href={`/students/view?id=${row.studentId}&tab=development`} className={cn(TILE_INTERACTIVE, 'block px-3.5 py-3')}>
        <span className="flex items-center justify-between gap-2">
          <span className="font-medium">{row.name}</span>
          <span className="text-xs tabular-nums text-muted-foreground">
            {row.assessedAt ? formatDate(row.assessedAt, 'd MMM') : t('development.classView.notAssessed')}
          </span>
        </span>
        {(row.assessedAt || (showAttention && row.attention)) && (
          <span className="mt-2 flex flex-wrap gap-1.5">
            {showAttention && row.attention && <Badge variant="info" size="sm">{t('development.classView.attentionBadge')}</Badge>}
            {domains.map((d) =>
              row.domains[d] ? (
                <span key={d} className="inline-flex items-center gap-1 text-[0.7rem] text-muted-foreground">
                  {t(domainKey(d))}
                  <BandChip band={row.domains[d]?.band} index={row.domains[d]?.index} />
                </span>
              ) : null,
            )}
          </span>
        )}
      </Link>
    </li>
  );
}

function RowsTable({ data, showAttention }: { data: ClassDevOverview; showAttention: boolean }) {
  const { t } = useI18n();
  // Shu chorakda o'tkazilmagan sohalar ustuni ko'rsatilmaydi.
  const domains = DOMAINS.filter((d) => data.rows.some((r) => r.domains[d]));
  return (
    <SectionCard title={t('development.classView.title')} description={showAttention ? t('development.indexScale') : t('development.classView.emotionalNote')} icon={<Users />}>
      <ul className="space-y-2 md:hidden">
        {data.rows.map((r) => (
          <MobileRow key={r.studentId} row={r} showAttention={showAttention} domains={domains} />
        ))}
      </ul>
      <div className="-mx-1 hidden overflow-x-auto px-1 md:block">
        <table className="w-full text-sm" style={{ minWidth: 300 + domains.length * 120 }}>
          <thead>
            <tr className="text-left text-xs text-muted-foreground">
              <th scope="col" className="pb-2 pl-1 font-medium">{t('development.classView.student')}</th>
              <th scope="col" className="pb-2 px-2 font-medium">{t('development.classView.assessedAt')}</th>
              {domains.map((d) => (
                <th key={d} scope="col" className="pb-2 px-1.5 font-medium">{t(domainKey(d))}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.rows.map((r) => (
              <StudentRow key={r.studentId} row={r} showAttention={showAttention} domains={domains} />
            ))}
          </tbody>
        </table>
      </div>
    </SectionCard>
  );
}

/** Sinf kesimi: psixolog — istalgan sinf; sinf rahbari — faqat o'z sinfi (tanlov yo'q). */
export function ClassView({ psychologist }: { psychologist: boolean }) {
  const { t, formatNumber } = useI18n();
  const options = useDevClassOptions();
  const terms = useDevTerms();
  const [classId, setClassId] = useState<string | undefined>();
  const [termKey, setTermKey] = useState<string | undefined>();
  useEffect(() => {
    if (!classId && options.data?.length) setClassId(psychologist ? options.data.find((c) => c.id === 'cls-7a')?.id ?? options.data[0]?.id : options.data[0]?.id);
  }, [classId, options.data, psychologist]);
  const view = useDevClass(classId, termKey);
  const data = view.data;

  if (options.error) return <ErrorState error={options.error} onRetry={() => void options.refetch()} />;
  if (!options.isLoading && !options.data?.length) {
    return (
      <Card>
        <EmptyState icon={<Users />} title={t('development.empty.fromGrade3')} description={t('development.empty.fromGrade3Hint')} />
      </Card>
    );
  }
  // Sinf rahbariga hissiy holat o'rtachasi kelmaydi (null yoki umuman yo'q) — taqqoslashda bu qator ko'rsatilmaydi.
  const compare = data?.domainAverages
    .filter((d) => psychologist || d.domain !== 'EMOTIONAL')
    .map((d) => ({ domain: d.domain, index: d.index, compare: data.schoolAverages[d.domain] ?? null }));

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-3">
        {psychologist && options.data && (
          <Select value={classId} onValueChange={(v) => setClassId(v)}>
            <SelectTrigger className="h-10 w-full sm:w-44" aria-label={t('development.classView.pick')}>
              <SelectValue placeholder={t('development.classView.pick')} />
            </SelectTrigger>
            <SelectContent>
              {options.data.map((c) => (
                <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
        <TermSelect value={data?.termKey ?? termKey} options={terms.data} onChange={setTermKey} />
      </div>
      {view.error ? (
        <ErrorState error={view.error} onRetry={() => void view.refetch()} />
      ) : !data ? (
        <Skeleton className="h-96 w-full rounded-2xl" />
      ) : data.assessed === 0 ? (
        <Card>
          <EmptyState icon={<ClipboardCheck />} title={t('development.empty.noResults')} description={t('development.empty.noResultsHint')} />
        </Card>
      ) : (
        <>
          <div className="grid gap-6 xl:grid-cols-3">
            <StatCard
              icon={<ClipboardCheck />}
              label={t('development.stats.assessed')}
              value={`${percent(data.assessed, data.total)}%`}
              hint={t('development.stats.assessedHint', { assessed: formatNumber(data.assessed), total: formatNumber(data.total) })}
              footer={<Progress value={percent(data.assessed, data.total)} />}
              className="self-start"
            />
            <div className="xl:col-span-2">
              <DomainAverages
                rows={compare}
                title={t('development.classView.compareTitle')}
                description={t('development.classView.compareHint')}
                mainLabel={`${t('development.classView.classAvg')} ${data.className}`}
                compareLabel={t('development.classView.schoolAvg')}
              />
            </div>
          </div>
          <RowsTable data={data} showAttention={psychologist} />
        </>
      )}
    </div>
  );
}
