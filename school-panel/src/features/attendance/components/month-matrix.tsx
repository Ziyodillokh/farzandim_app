'use client';

import type { AttendanceStatus } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { ALL_STATUSES, fromIsoDate, rateTextClass, STATUS_TONE } from '../lib';
import type { MonthReport } from './report-types';

const SUMMARY_FIELD: Record<AttendanceStatus, 'present' | 'late' | 'absent' | 'leftEarly' | 'excused'> = {
  PRESENT: 'present',
  LATE: 'late',
  ABSENT: 'absent',
  LEFT_EARLY: 'leftEarly',
  EXCUSED: 'excused',
};

/** Holat belgilari va ranglari (matritsa ostida). */
export function MatrixLegend() {
  const { t } = useI18n();
  return (
    <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-xs">
      <span className="font-semibold text-muted-foreground">{t('attendance.reports.legend')}:</span>
      {ALL_STATUSES.map((s) => (
        <span key={s} className="inline-flex items-center gap-1.5">
          <span className={cn('flex h-5 w-5 items-center justify-center rounded font-bold', STATUS_TONE[s].cell)}>{t(`attendance.reports.codes.${s}`)}</span>
          {t(`enums.attendanceStatus.${s}`)}
        </span>
      ))}
    </div>
  );
}

/** O'quvchilar × kunlar jadvali: rangli katakchalar, har o'quvchi jami va foizi. */
export function MonthMatrix({ report }: { report: MonthReport }) {
  const { t, formatDate } = useI18n();
  const head = 'sticky top-0 bg-card px-1 py-2 text-center text-2xs font-semibold text-muted-foreground';

  return (
    <div className="overflow-x-auto print:overflow-visible">
      <table className="w-full border-separate border-spacing-0 text-sm print:text-[10px]">
        <thead>
          <tr>
            <th className={cn(head, 'left-0 z-20 min-w-[200px] border-b pl-4 text-left print:min-w-[140px]')}>{t('attendance.reports.columns.student')}</th>
            {report.days.map((d) => {
              const date = fromIsoDate(d);
              return (
                <th key={d} className={cn(head, 'z-10 min-w-[30px] border-b print:min-w-0')}>
                  <span className="block text-xs text-foreground">{formatDate(date, 'd')}</span>
                  <span className="block font-normal capitalize">{formatDate(date, 'EEEEEE')}</span>
                </th>
              );
            })}
            {ALL_STATUSES.map((s) => (
              <th key={s} className={cn(head, 'z-10 min-w-[34px] border-b border-l', STATUS_TONE[s].text)}>
                {t(`attendance.reports.codes.${s}`)}
              </th>
            ))}
            <th className={cn(head, 'z-10 min-w-[48px] border-b pr-4')}>{t('attendance.reports.columns.rate')}</th>
          </tr>
        </thead>
        <tbody>
          {report.rows.map((row, i) => (
            <tr key={row.studentId} className="group">
              <td className="sticky left-0 z-10 border-b bg-card py-1.5 pl-4 pr-3 group-hover:bg-muted">
                <span className="mr-2 inline-block w-5 text-right text-xs tabular-nums text-muted-foreground">{i + 1}</span>
                <span className="font-medium">{row.name}</span>
              </td>
              {row.cells.map((status, j) => (
                <td key={report.days[j]} className="border-b px-0.5 py-1 text-center group-hover:bg-muted/50">
                  <span
                    title={`${formatDate(fromIsoDate(report.days[j] ?? ''), 'd MMMM')} — ${status ? t(`enums.attendanceStatus.${status}`) : t('attendance.pending')}`}
                    className={cn(
                      'mx-auto flex h-6 w-6 items-center justify-center rounded-md text-2xs font-bold print:h-4 print:w-4 print:rounded-sm',
                      STATUS_TONE[status ?? 'PENDING'].cell,
                    )}
                  >
                    {t(`attendance.reports.codes.${status ?? 'none'}`)}
                  </span>
                </td>
              ))}
              {ALL_STATUSES.map((s) => (
                <td key={s} className="border-b border-l px-1 text-center text-xs tabular-nums group-hover:bg-muted/50">
                  {row.summary[SUMMARY_FIELD[s]] || <span className="text-muted-foreground/50">0</span>}
                </td>
              ))}
              <td className={cn('border-b pr-4 text-center text-xs font-semibold tabular-nums group-hover:bg-muted/50', rateTextClass(row.rate))}>{row.rate}%</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
