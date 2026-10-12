'use client';

import { BellRing, History, LogOut, PencilLine, ShieldOff, Wallet, type LucideIcon } from 'lucide-react';
import { useMemo, useState } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { EarlyExitBadge } from '@/components/common/status-badges';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import type { StudentHistoryItem, StudentHistoryKind, StudentPaymentStatus } from '@/data/mock/services/student-360';
import { INNER_TILE } from '@/features/classes/styles';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useStudentHistory } from '../hooks';

/** Faqat ko'k/osmon/moviy tuslar (brend qoidasi). */
const KIND_STYLE: Record<StudentHistoryKind, { icon: LucideIcon; tone: string }> = {
  EARLY_EXIT: { icon: LogOut, tone: 'bg-primary/10 text-primary ring-primary/20' },
  CORRECTION: { icon: PencilLine, tone: 'bg-sky-500/10 text-sky-700 ring-sky-500/20 dark:text-sky-300' },
  NOTIFICATION: { icon: BellRing, tone: 'bg-cyan-500/10 text-cyan-700 ring-cyan-500/20 dark:text-cyan-300' },
  EXCEPTION: { icon: ShieldOff, tone: 'bg-blue-500/10 text-blue-700 ring-blue-500/20 dark:text-blue-300' },
  PAYMENT: { icon: Wallet, tone: 'bg-sky-500/10 text-sky-700 ring-sky-500/20 dark:text-sky-300' },
};

type Filter = StudentHistoryKind | 'ALL';

function localDay(stamp: string): string {
  const d = new Date(stamp);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function ItemBody({ item }: { item: StudentHistoryItem }) {
  const { t, formatDate } = useI18n();
  switch (item.kind) {
    case 'EARLY_EXIT':
      return (
        <>
          <p className="text-sm">{t('students.history.earlyExit', { time: item.time, reason: item.reason })}</p>
          <p className="text-xs text-muted-foreground">
            {t('students.history.pickupBy', { name: item.pickupBy })}
            {item.decidedByName && ` · ${t('students.history.decidedBy', { name: item.decidedByName })}`}
          </p>
        </>
      );
    case 'CORRECTION':
      return (
        <>
          <p className="text-sm font-medium">{t('students.history.correction', { date: formatDate(item.date, 'dd.MM.yyyy'), from: t(`enums.attendanceStatus.${item.from}`), to: t(`enums.attendanceStatus.${item.to}`) })}</p>
          <p className="text-xs text-muted-foreground">
            {t('students.history.reason', { reason: item.reason })} · {t('students.history.by', { name: item.byName })}
          </p>
        </>
      );
    case 'NOTIFICATION':
      return (
        <>
          <p className="text-sm">{t(`attendance.notifications.kind.${item.notification}`)}</p>
          <p className="text-xs text-muted-foreground">{item.guardianName}</p>
        </>
      );
    case 'EXCEPTION':
      return (
        <>
          <p className="text-sm font-medium tabular-nums">{t('students.history.exception', { from: formatDate(item.from, 'HH:mm'), until: formatDate(item.until, 'HH:mm') })}</p>
          <p className="text-xs text-muted-foreground">
            {t('students.history.reason', { reason: item.reason })} · {t('students.history.by', { name: item.byName })}
          </p>
        </>
      );
    case 'PAYMENT':
      return (
        <>
          <p className="text-sm">{t(`students.history.payment.${item.action}`)}</p>
          <p className="text-xs text-muted-foreground">
            {item.note && `${item.note} · `}
            {t('students.history.by', { name: item.byName })}
          </p>
        </>
      );
  }
}

function ItemBadge({ item }: { item: StudentHistoryItem }) {
  const { t } = useI18n();
  if (item.kind === 'EARLY_EXIT') return <EarlyExitBadge status={item.status} />;
  if (item.kind === 'NOTIFICATION') {
    return <Badge variant={item.delivered ? 'default' : 'outline'} size="sm">{item.delivered ? t('students.history.delivered') : t('students.history.notDelivered')}</Badge>;
  }
  if (item.kind === 'EXCEPTION' && item.revoked) return <Badge variant="outline" size="sm">{t('students.history.revoked')}</Badge>;
  return null;
}

function TimelineItem({ item }: { item: StudentHistoryItem }) {
  const { t, formatDate } = useI18n();
  const { icon: Icon, tone } = KIND_STYLE[item.kind];
  return (
    <li className="group relative flex gap-3 pb-5 last:pb-0">
      <span aria-hidden className="absolute bottom-0 left-[17px] top-10 w-px bg-border/70 group-last:hidden dark:bg-white/[0.08]" />
      <span className={cn('relative flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ring-1 ring-inset [&_svg]:size-4', tone)}>
        <Icon aria-hidden />
      </span>
      <div className={cn('min-w-0 flex-1 px-3.5 py-2.5', INNER_TILE)}>
        <div className="flex flex-wrap items-center justify-between gap-2">
          <p className="text-2xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">{t(`students.history.kinds.${item.kind}`)}</p>
          <div className="flex items-center gap-2">
            <ItemBadge item={item} />
            <time dateTime={item.at} className="font-display text-xs font-semibold tabular-nums text-muted-foreground">
              {formatDate(item.at, 'HH:mm')}
            </time>
          </div>
        </div>
        <div className="mt-1 space-y-0.5">
          <ItemBody item={item} />
        </div>
      </div>
    </li>
  );
}

function PaymentCard({ payment }: { payment: StudentPaymentStatus }) {
  const { t, formatDate } = useI18n();
  return (
    <div className={cn('mb-5 flex flex-wrap items-center gap-3 p-4', INNER_TILE)}>
      <span className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ring-1 ring-inset [&_svg]:size-4', KIND_STYLE.PAYMENT.tone)}>
        <Wallet aria-hidden />
      </span>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">{t('students.history.paymentTitle')}</p>
        <p className="text-xs text-muted-foreground">
          {t('students.history.nextDate', { date: formatDate(payment.nextDate, 'd MMMM yyyy') })}
          {payment.prepaidMonths > 0 && ` · ${t('students.history.prepaid', { months: payment.prepaidMonths })}`}
        </p>
      </div>
      <Badge variant={payment.paused ? 'outline' : 'default'}>{payment.paused ? t('students.history.paused') : t('students.history.active')}</Badge>
    </div>
  );
}

/** Tarix lentasi: kunlar bo'yicha guruhlangan, turi bo'yicha filtr. */
export function StudentHistory({ studentId }: { studentId: string }) {
  const { t, formatDate } = useI18n();
  const history = useStudentHistory(studentId);
  const [filter, setFilter] = useState<Filter>('ALL');
  const items = history.data?.items;

  const kinds = useMemo(() => [...new Set((items ?? []).map((i) => i.kind))], [items]);
  const days = useMemo(() => {
    const visible = (items ?? []).filter((i) => filter === 'ALL' || i.kind === filter);
    const groups = new Map<string, StudentHistoryItem[]>();
    for (const item of visible) groups.set(localDay(item.at), [...(groups.get(localDay(item.at)) ?? []), item]);
    return [...groups.entries()];
  }, [items, filter]);

  return (
    <SectionCard icon={<History />} title={t('students.history.title')} description={t('students.history.description')}>
      {history.isError ? (
        <ErrorState error={history.error} onRetry={() => void history.refetch()} />
      ) : !history.data ? (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-16 w-full rounded-xl" />
          ))}
        </div>
      ) : (
        <>
          {history.data.payment && <PaymentCard payment={history.data.payment} />}
          {kinds.length > 1 && (
            <div className="mb-5 flex flex-wrap gap-1.5" role="radiogroup" aria-label={t('students.history.title')}>
              {(['ALL', ...kinds] as Filter[]).map((k) => (
                <button
                  key={k}
                  type="button"
                  role="radio"
                  aria-checked={filter === k}
                  onClick={() => setFilter(k)}
                  className={cn(
                    'rounded-full px-3 py-1 text-xs font-semibold ring-1 ring-inset transition-colors',
                    filter === k ? 'bg-primary/10 text-primary ring-primary/25' : 'bg-white/50 text-muted-foreground ring-border/60 hover:text-foreground dark:bg-white/[0.03]',
                  )}
                >
                  {k === 'ALL' ? t('students.history.all') : t(`students.history.kinds.${k}`)}
                </button>
              ))}
            </div>
          )}
          {days.length === 0 ? (
            <EmptyState icon={<History />} title={t('students.history.empty')} description={t('students.history.emptyHint')} className="py-10" />
          ) : (
            <div className="space-y-6">
              {days.map(([day, list]) => (
                <section key={day} aria-label={formatDate(`${day}T12:00:00`, 'd MMMM yyyy')}>
                  <h3 className="mb-3 text-xs font-semibold text-muted-foreground">{formatDate(`${day}T12:00:00`, 'd MMMM, EEEE')}</h3>
                  <ol>
                    {list.map((item) => (
                      <TimelineItem key={item.id} item={item} />
                    ))}
                  </ol>
                </section>
              ))}
            </div>
          )}
        </>
      )}
    </SectionCard>
  );
}
