'use client';

import { CalendarOff, Clock4, LogIn, UserCheck } from 'lucide-react';

import type { KioskStats as Stats } from '@/data/mock/services/attendance';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';

/** Bugungi hisoblagichlar (keldi / kechikdi) va oxirgi kirishlar lentasi. */
export function KioskStats({ stats }: { stats: Stats | undefined }) {
  const { t, formatNumber, formatDate } = useI18n();
  const arrived = stats?.arrived ?? 0;
  const expected = stats?.expected ?? 0;
  const share = percent(arrived, expected);

  if (stats && expected === 0) {
    return (
      <div className="flex items-center justify-center gap-3 rounded-[2rem] border border-white/10 bg-white/[0.04] p-6 text-lg text-white/70">
        <CalendarOff className="h-6 w-6" />
        {t('attendance.kiosk.noSchoolDay')}
      </div>
    );
  }

  return (
    <div className="grid gap-4 rounded-[2rem] border border-white/10 bg-white/[0.04] p-5 backdrop-blur lg:grid-cols-[auto_auto_minmax(0,1fr)] lg:items-center lg:gap-8 md:p-6">
      <div className="flex items-center gap-4">
        <span className="flex h-14 w-14 items-center justify-center rounded-2xl bg-emerald-400/15 text-emerald-300">
          <UserCheck className="h-7 w-7" />
        </span>
        <div>
          <p className="text-sm text-white/60">{t('attendance.kiosk.arrived')}</p>
          <p className="font-display text-4xl font-semibold tabular-nums">
            {formatNumber(arrived)}
            <span className="ml-2 text-base font-medium text-white/45">{share}%</span>
          </p>
          <div className="mt-1.5 h-1.5 w-40 overflow-hidden rounded-full bg-white/10">
            <div className="h-full rounded-full bg-emerald-400 transition-[width] duration-700" style={{ width: `${share}%` }} />
          </div>
          <p className="mt-1 text-xs text-white/45">{t('attendance.kiosk.expected', { count: formatNumber(Math.max(0, expected - arrived)) })}</p>
        </div>
      </div>

      <div className="flex items-center gap-4">
        <span className="flex h-14 w-14 items-center justify-center rounded-2xl bg-amber-400/15 text-amber-300">
          <Clock4 className="h-7 w-7" />
        </span>
        <div>
          <p className="text-sm text-white/60">{t('attendance.kiosk.late')}</p>
          <p className="font-display text-4xl font-semibold tabular-nums">{formatNumber(stats?.late ?? 0)}</p>
        </div>
      </div>

      <div className="min-w-0">
        <p className="mb-2 text-xs font-semibold uppercase tracking-[0.16em] text-white/45">{t('attendance.kiosk.recent')}</p>
        {stats && stats.recent.length === 0 ? (
          <p className="text-sm text-white/45">{t('attendance.kiosk.recentEmpty')}</p>
        ) : (
          <ul className="flex gap-2 overflow-hidden">
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
                  <p className="text-2xs text-white/50">
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
