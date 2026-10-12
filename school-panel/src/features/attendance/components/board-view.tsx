'use client';

import { QrCode, SearchX } from 'lucide-react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { useMemo, useState } from 'react';

import { useCan } from '@/auth/use-session';
import { Can } from '@/auth/can';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { FilterSelect } from '@/components/common/toolbar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import type { IsoDate } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useBoard } from '../hooks';
import { parseDateParam, sumCounts, useClockToday } from '../lib';
import { ClassCard } from './class-card';
import { DateNav } from './date-nav';
import { DayKpis } from './day-kpis';
import { FeedSidePanel } from './feed-side-panel';
import { LiveIndicator } from './live-indicator';

/** Bugungi taxta: KPI, smena filtri, sinf kartochkalari va jonli oqim. */
export function BoardView() {
  const { t } = useI18n();
  const can = useCan();
  const router = useRouter();
  const params = useSearchParams();
  const today = useClockToday();
  const canHistory = can('attendance.history');
  const date = canHistory ? parseDateParam(params.get('date'), today) : undefined;
  const day = date ?? today;
  const [shiftId, setShiftId] = useState<string>();
  const board = useBoard(date);

  const allRows = board.data?.rows;
  const rows = useMemo(() => (allRows ?? []).filter((r) => !shiftId || r.shiftId === shiftId), [allRows, shiftId]);
  const totals = useMemo(() => sumCounts(rows.filter((r) => r.schoolDay).map((r) => r.counts)), [rows]);
  const shifts = useMemo(() => {
    const map = new Map<string, string>();
    for (const r of allRows ?? []) map.set(r.shiftId, r.shiftName);
    return [...map].map(([value, label]) => ({ value, label }));
  }, [allRows]);

  const setDate = (next: IsoDate) => router.replace(next >= today ? '/attendance' : `/attendance?date=${next}`, { scroll: false });
  const dateQuery = date ? `&date=${date}` : '';

  return (
    <>
      <PageHeader
        title={t('attendance.title')}
        subtitle={t('attendance.subtitle')}
        badge={date ? <Badge variant="secondary">{t('attendance.board.pastBadge')}</Badge> : <LiveIndicator />}
        actions={
          <>
            <DateNav value={day} today={today} onChange={setDate} canHistory={canHistory} />
            <Can perm="attendance.kiosk">
              <Button asChild variant="outline">
                <Link href="/kiosk" target="_blank" rel="noopener">
                  <QrCode />
                  {t('attendance.openKiosk')}
                </Link>
              </Button>
            </Can>
          </>
        }
      />

      <DayKpis counts={totals} loading={board.isLoading} />

      <div className="grid items-start gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
        <section className="min-w-0">
          <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
            <div>
              <h2 className="font-semibold">{t('attendance.board.classesTitle')}</h2>
              <p className="text-xs text-muted-foreground">{t('attendance.board.classesHint')}</p>
            </div>
            {shifts.length > 1 && (
              <FilterSelect value={shiftId} onChange={setShiftId} options={shifts} allLabel={t('attendance.board.shiftAll')} className="sm:w-44" />
            )}
          </div>

          {board.error ? (
            <ErrorState error={board.error} onRetry={() => void board.refetch()} />
          ) : board.isLoading && !board.data ? (
            <div className="grid gap-4 sm:grid-cols-2 2xl:grid-cols-3">
              {Array.from({ length: 6 }).map((_, i) => (
                <Skeleton key={i} className="h-44 rounded-2xl" />
              ))}
            </div>
          ) : rows.length === 0 ? (
            <EmptyState icon={<SearchX />} title={t('attendance.board.emptyTitle')} description={t('attendance.board.emptyHint')} />
          ) : (
            <div className="grid gap-4 sm:grid-cols-2 2xl:grid-cols-3">
              {rows.map((row) => (
                <ClassCard key={row.classId} row={row} href={`/attendance/class?id=${row.classId}${dateQuery}`} />
              ))}
            </div>
          )}
        </section>

        <FeedSidePanel className="xl:sticky xl:top-24" />
      </div>
    </>
  );
}
