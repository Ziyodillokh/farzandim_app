'use client';

import { CalendarOff, Clock4, LogIn, UserCheck } from 'lucide-react';

import type { KioskStats as Stats } from '@/data/mock/services/attendance';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';

/** Bugungi hisoblagichlar (keldi / kechikdi) va oxirgi kirishlar lentasi — ixcham shisha qator. */
export function KioskStats({ stats }: { stats: Stats | undefined }) {
  const { t, formatNumber, formatDate } = useI18n();
  const arrived = stats?.arrived ?? 0;
  const expected = stats?.expected ?? 0;
  const share = percent(arrived, expected);

  if (stats && expected === 0) {
    return (
      <div className="glass flex shrink-0 items-center justify-center gap-3 rounded-[1.75rem] p-5 text-lg text-white/75">
        <CalendarOff className="h-6 w-6 text-brand-300" />
        {t('attendance.kiosk.noSchoolDay')}
      </div>
    );
  }

  return (
    <div className="glass grid shrink-0 gap-4 rounded-[1.75rem] px-5 py-4 md:grid-cols-[auto_auto_minmax(0,1fr)] md:items-center md:gap-7 xl:px-6">
      <div className="flex items-center gap-3.5">
        <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-emerald-400/15 text-emerald-300 ring-1 ring-inset ring-emerald-300/20">
          <UserCheck className="h-5 w-5" />
        </span>
        <div>
          <p className="text-xs font-medium text-white/60">{t('attendance.kiosk.arrived')}</p>
          <p className="font-display text-3xl font-semibold leading-tight tabular-nums">
            {formatNumber(arrived)}
            <span className="ml-2 text-sm font-medium text-white/50">{share}%</span>
          </p>
          <div className="mt-1 flex items-center gap-2">
            <div className="h-1.5 w-32 overflow-hidden rounded-full bg-white/10">
              <div className="h-full rounded-full bg-emerald-400 transition-[width] duration-700" style={{ width: `${share}%` }} />
            </div>
            <span className="text-2xs text-white/50">{t('attendance.kiosk.expected', { count: formatNumber(Math.max(0, expected - arrived)) })}</span>
          </div>
        </div>
      </div>

      <div className="flex items-center gap-3.5 md:border-l md:border-white/10 md:pl-7">
        <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-amber-400/15 text-amber-300 ring-1 ring-inset ring-amber-300/20">
          <Clock4 className="h-5 w-5" />
        </span>
        <div>
          <p className="text-xs font-medium text-white/60">{t('attendance.kiosk.late')}</p>
          <p className="font-display text-3xl font-semibold leading-tight tabular-nums">{formatNumber(stats?.late ?? 0)}</p>
        </div>
      </div>

      <div className="min-w-0 md:border-l md:border-white/10 md:pl-7">
        <p className="mb-2 text-2xs font-semibold uppercase tracking-[0.18em] text-brand-300/80">{t('attendance.kiosk.recent')}</p>
        {stats && stats.recent.length === 0 ? (
          <p className="text-sm text-white/50">{t('attendance.kiosk.recentEmpty')}</p>
        ) : (
          <ul className="flex gap-2 overflow-hidden [mask-image:linear-gradient(90deg,#000_85%,transparent)]">
            {stats?.recent.map((e) => (
              <li
                key={e.id}
                className={cn(
                  'flex min-w-0 shrink-0 items-center gap-2 rounded-xl border border-white/10 bg-white/[0.05] px-3 py-2 animate-slide-in-right',
                  e.late && 'border-amber-300/25',
                )}
              >
                <LogIn className={cn('h-4 w-4 shrink-0', e.late ? 'text-amber-300' : 'text-emerald-300')} />
                <div className="min-w-0">
                  <p className="max-w-[150px] truncate text-sm font-medium">{e.studentName}</p>
                  <p className="text-2xs text-white/55">
                    {e.className} · {formatDate(e.at, 'HH:mm')}
                  </p>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
