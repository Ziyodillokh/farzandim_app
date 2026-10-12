'use client';

import { CalendarCheck2, GraduationCap, Smartphone, UsersRound } from 'lucide-react';

import { StatCard } from '@/components/common/stat-card';
import { Progress } from '@/components/ui/progress';
import type { ClassBoardRow } from '@/data/mock/services/attendance';
import type { ClassRow } from '@/data/mock/services/classes';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';

/** Ko'rinib turgan sinflar bo'yicha umumiy ko'rsatkichlar. */
export function ClassesStats({
  rows,
  board,
  loading,
  showAttendance,
}: {
  rows: ClassRow[];
  board: ClassBoardRow[] | undefined;
  loading: boolean;
  showAttendance: boolean;
}) {
  const { t, tc, formatNumber } = useI18n();
  const students = rows.reduce((sum, r) => sum + r.size, 0);
  const weighted = (key: 'linkedRate' | 'phoneRate') =>
    students ? Math.round(rows.reduce((sum, r) => sum + r[key] * r.size, 0) / students) : 0;
  const linked = weighted('linkedRate');
  const phones = weighted('phoneRate');

  const visible = new Set(rows.map((r) => r.id));
  const day = (board ?? []).filter((b) => visible.has(b.classId) && b.schoolDay);
  const sum = (pick: (b: ClassBoardRow) => number) => day.reduce((acc, b) => acc + pick(b), 0);
  const attended = sum((b) => b.counts.present + b.counts.late + b.counts.leftEarly);
  const decided = sum((b) => b.counts.total - b.counts.pending);
  const absent = sum((b) => b.counts.absent);

  return (
    <div className={cn('mb-6 grid gap-4 sm:grid-cols-2', showAttendance ? 'xl:grid-cols-4' : 'xl:grid-cols-3')}>
      <StatCard
        icon={<GraduationCap />}
        label={t('classes.stats.classes')}
        value={formatNumber(rows.length)}
        hint={tc('common.studentsCount', students)}
        loading={loading}
      />
      <StatCard
        icon={<UsersRound />}
        tone="success"
        label={t('classes.stats.linked')}
        value={`${linked}%`}
        hint={t('classes.stats.linkedHint')}
        loading={loading}
        footer={<Progress value={linked} className="h-1.5" indicatorClassName="bg-success" />}
      />
      <StatCard
        icon={<Smartphone />}
        tone="info"
        label={t('classes.stats.phones')}
        value={`${phones}%`}
        hint={t('classes.stats.avgSize', { count: rows.length ? Math.round(students / rows.length) : 0 })}
        loading={loading}
        footer={<Progress value={phones} className="h-1.5" indicatorClassName="bg-info" />}
      />
      {showAttendance && (
        <StatCard
          icon={<CalendarCheck2 />}
          tone="warning"
          label={t('classes.stats.attendance')}
          value={decided ? `${percent(attended, decided)}%` : '—'}
          hint={t('classes.stats.attendanceHint', { present: formatNumber(attended), absent: formatNumber(absent) })}
          loading={loading || !board}
        />
      )}
    </div>
  );
}
