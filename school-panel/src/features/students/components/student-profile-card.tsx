'use client';

import { UserRound } from 'lucide-react';
import type { ReactNode } from 'react';

import { useCan } from '@/auth/use-session';
import { SectionCard } from '@/components/common/section-card';
import { StaffAvatar } from '@/components/common/staff-avatar';
import { clockToday } from '@/data/mock/clock';
import type { StudentDetail } from '@/data/mock/services/students';
import { useHomeroomOf } from '@/features/classes/hooks';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { DeviceIcon } from './device-icon';

function InfoRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 py-3 text-sm">
      <span className="text-muted-foreground">{label}</span>
      <span className="min-w-0 text-right font-medium">{value}</span>
    </div>
  );
}

function ageOf(birthDate: string): number {
  const [y, m, d] = birthDate.split('-').map(Number);
  const [ty, tm, td] = clockToday().split('-').map(Number);
  let age = (ty ?? 0) - (y ?? 0);
  if ((tm ?? 0) < (m ?? 0) || ((tm ?? 0) === (m ?? 0) && (td ?? 0) < (d ?? 0))) age -= 1;
  return age;
}

function Homeroom({ student }: { student: StudentDetail }) {
  const can = useCan();
  const homeroomId = useHomeroomOf(student.classId, can('classes.view'));
  if (!student.homeroomName) return <>—</>;
  return (
    <span className="inline-flex min-w-0 items-center gap-2">
      <StaffAvatar staffId={homeroomId.data ?? null} name={student.homeroomName} size="xs" />
      <span className="truncate">{student.homeroomName}</span>
    </span>
  );
}

/** O'quvchi profili: sinf, smena, sinf rahbari (+ psixologdan tashqari — shaxsiy maydonlar). */
export function StudentProfileCard({ student: s, minimal }: { student: StudentDetail; minimal: boolean }) {
  const { t, formatDate } = useI18n();
  const column = 'divide-y divide-border/60 dark:divide-white/[0.06]';
  return (
    <SectionCard icon={<UserRound />} title={t('students.detail.profile')}>
      <div className="grid gap-x-10 sm:grid-cols-2">
        <div className={column}>
          <InfoRow label={t('students.fields.class')} value={s.className} />
          <InfoRow label={t('students.detail.shift')} value={s.shiftName} />
          {!minimal && <InfoRow label={t('students.detail.homeroom')} value={<Homeroom student={s} />} />}
        </div>
        {minimal && (
          <div className={cn(column, 'border-t border-border/60 sm:border-t-0 dark:border-white/[0.06]')}>
            <InfoRow label={t('students.detail.homeroom')} value={<Homeroom student={s} />} />
          </div>
        )}
        {!minimal && (
          <div className={cn(column, 'border-t border-border/60 sm:border-t-0 dark:border-white/[0.06]')}>
            <InfoRow label={t('students.fields.gender')} value={t(`enums.gender.${s.gender}`)} />
            <InfoRow
              label={t('students.fields.birthDate')}
              value={`${formatDate(s.birthDate, 'dd.MM.yyyy')} · ${t('students.age', { age: ageOf(s.birthDate) })}`}
            />
            <InfoRow label={t('students.fields.device')} value={<DeviceIcon device={s.device} showLabel />} />
          </div>
        )}
      </div>
    </SectionCard>
  );
}
