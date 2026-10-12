'use client';

import { Lock } from 'lucide-react';
import { Bar, BarChart, LabelList, ResponsiveContainer, XAxis, YAxis } from 'recharts';

import { SectionCard } from '@/components/common/section-card';
import { Progress } from '@/components/ui/progress';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import type { MonthlyReport } from '@/data/mock/services/reports';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const RATE_WARN = 90;

type Section<K extends keyof MonthlyReport> = NonNullable<MonthlyReport[K]>;

export function Metric({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-3 border-b py-2.5 text-sm last:border-0">
      <span className="text-muted-foreground">{label}</span>
      <span className="font-semibold tabular-nums">{value}</span>
    </div>
  );
}

export function AttendanceTable({ data, print }: { data: Section<'attendance'>; print: boolean }) {
  const { t } = useI18n();
  const cols = ['students', 'rate', 'late', 'absent', 'excused'] as const;
  return (
    <SectionCard title={t('reports.attendance.title')} bodyClassName="p-0">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{t('reports.attendance.columns.class')}</TableHead>
            {cols.map((c) => (
              <TableHead key={c} className="text-right">
                {t(`reports.attendance.columns.${c}`)}
              </TableHead>
            ))}
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.byClass.map((r) => (
            <TableRow key={r.classId} className={print ? 'break-inside-avoid' : undefined}>
              <TableCell className="py-2 font-medium">{r.className}</TableCell>
              <TableCell className="py-2 text-right tabular-nums">{r.students}</TableCell>
              <TableCell className={cn('py-2 text-right font-medium tabular-nums', r.rate < RATE_WARN && 'text-warning')}>{r.rate}%</TableCell>
              <TableCell className="py-2 text-right tabular-nums">{r.late}</TableCell>
              <TableCell className="py-2 text-right tabular-nums">{r.absent}</TableCell>
              <TableCell className="py-2 text-right tabular-nums">{r.excused}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </SectionCard>
  );
}

export function WeekdayChart({ data, print }: { data: Section<'attendance'>; print: boolean }) {
  const { t } = useI18n();
  const rows = data.byWeekday.map((w) => ({ ...w, label: t(`enums.weekdayShort.${w.weekday}`) }));
  return (
    <SectionCard title={t('reports.attendance.weekday')} className="break-inside-avoid">
      <div className="h-48">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={rows} margin={{ top: 22, right: 4, left: 4, bottom: 0 }}>
            <XAxis dataKey="label" interval={0} tickLine={false} axisLine={false} tick={{ fontSize: 12, fill: 'hsl(var(--muted-foreground))' }} />
            <YAxis domain={[0, 100]} hide />
            <Bar dataKey="rate" fill="hsl(var(--chart-1))" radius={[6, 6, 0, 0]} maxBarSize={34} isAnimationActive={!print}>
              <LabelList dataKey="rate" position="top" formatter={(v: number) => `${v}%`} fontSize={11} fill="hsl(var(--foreground))" />
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
    </SectionCard>
  );
}

export function ParentsTable({ data }: { data: Section<'parents'> }) {
  const { t } = useI18n();
  return (
    <SectionCard title={t('reports.parents.title')} bodyClassName="p-0">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{t('reports.parents.columns.class')}</TableHead>
            <TableHead className="text-right">{t('reports.parents.columns.linked')}</TableHead>
            <TableHead className="w-32">{t('reports.parents.columns.rate')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.byClass.map((r) => (
            <TableRow key={r.classId} className="break-inside-avoid">
              <TableCell className="py-1.5 font-medium">{r.className}</TableCell>
              <TableCell className="py-1.5 text-right tabular-nums">
                {r.linked}/{r.total}
              </TableCell>
              <TableCell className="py-1.5">
                <div className="flex items-center gap-2">
                  <Progress value={r.rate} className="h-1.5" indicatorClassName="bg-info" />
                  <span className="w-9 text-right text-xs tabular-nums">{r.rate}%</span>
                </div>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </SectionCard>
  );
}

export function SchoolModeSection({ data }: { data: Section<'schoolMode'> }) {
  const { t } = useI18n();
  return (
    <SectionCard title={t('reports.schoolMode.title')} className="break-inside-avoid">
      <Metric label={t('reports.schoolMode.applied')} value={data.applied} />
      <Metric label={t('reports.schoolMode.noPermission')} value={data.noPermission} />
      <Metric label={t('reports.schoolMode.offline')} value={data.offline} />
      <Metric label={t('reports.schoolMode.noPhone')} value={data.noPhone} />
      <Metric label={t('reports.schoolMode.exceptions')} value={data.exceptions} />
      <Metric label={t('reports.schoolMode.changes')} value={data.changes} />
    </SectionCard>
  );
}

export function MessagesSection({ data }: { data: Section<'messages'> }) {
  const { t, formatNumber } = useI18n();
  return (
    <SectionCard title={t('reports.messages.title')} className="break-inside-avoid">
      <Metric label={t('reports.messages.announcements')} value={data.announcements} />
      <Metric label={t('reports.messages.recipients')} value={formatNumber(data.recipients)} />
      <Metric label={t('reports.messages.delivery')} value={`${data.deliveryRate}%`} />
      <Metric label={t('reports.messages.read')} value={`${data.readRate}%`} />
      <Metric label={t('reports.messages.reminders')} value={data.reminders} />
    </SectionCard>
  );
}

export function LearningSection({ data }: { data: Section<'learning'> }) {
  const { t, formatNumber } = useI18n();
  return (
    <SectionCard title={t('reports.learning.title')} className="break-inside-avoid">
      <Metric label={t('reports.learning.active')} value={data.avgActiveStudents} />
      <Metric label={t('reports.learning.tasks')} value={formatNumber(data.completedTasks)} />
      <Metric label={t('reports.learning.score')} value={`${data.avgScore}%`} />
      <Metric label={t('reports.learning.assignments')} value={data.assignments} />
    </SectionCard>
  );
}

export function CareSection({ data }: { data: Section<'care'> }) {
  const { t } = useI18n();
  return (
    <SectionCard title={t('reports.care.title')} className="break-inside-avoid">
      <div className="grid gap-6 md:grid-cols-5">
        <div className="md:col-span-2">
          <Metric label={t('reports.care.surveys')} value={data.surveys} />
          <Metric label={t('reports.care.participation')} value={`${data.participation}%`} />
          <Metric label={t('reports.care.wellbeing')} value={data.wellbeing === null ? '—' : `${data.wellbeing}%`} />
          <Metric label={t('reports.care.requests')} value={data.requests} />
        </div>
        <div className="md:col-span-3">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="px-2">{t('reports.care.group')}</TableHead>
                <TableHead className="px-2 text-right">{t('reports.care.respondents')}</TableHead>
                <TableHead className="px-2 text-right">{t('reports.care.wellbeing')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.groups.map((g) => (
                <TableRow key={g.key}>
                  <TableCell className="px-2 py-2">{t(`enums.ageGroup.${g.key}`)}</TableCell>
                  <TableCell className="px-2 py-2 text-right tabular-nums">{g.hidden ? '—' : g.respondents}</TableCell>
                  <TableCell className="px-2 py-2 text-right">
                    {g.hidden ? (
                      <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
                        <Lock className="h-3 w-3" />
                        {t('reports.care.hidden')}
                      </span>
                    ) : (
                      <span className="font-medium tabular-nums">{g.wellbeing === null ? '—' : `${g.wellbeing}%`}</span>
                    )}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      </div>
      <p className="mt-4 flex items-start gap-2 text-xs text-muted-foreground">
        <Lock className="mt-0.5 h-3 w-3 shrink-0" />
        {t('reports.care.note')}
      </p>
    </SectionCard>
  );
}
