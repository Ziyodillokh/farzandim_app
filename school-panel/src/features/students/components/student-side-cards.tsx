'use client';

import { Clock, Lock, ShieldCheck, Smartphone, Timer } from 'lucide-react';

import { SectionCard } from '@/components/common/section-card';
import { AttendanceBadge, DeviceModeBadge } from '@/components/common/status-badges';
import type { StudentDetail } from '@/data/mock/services/students';
import { INNER_TILE } from '@/features/classes/styles';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const LABEL = 'text-2xs font-semibold uppercase tracking-[0.08em] text-muted-foreground';

export function StudentTodayCard({ student: s }: { student: StudentDetail }) {
  const { t } = useI18n();
  return (
    <SectionCard icon={<Clock />} title={t('students.detail.today')}>
      <div className={cn('flex items-center justify-between gap-3 px-4 py-3', INNER_TILE)}>
        <AttendanceBadge status={s.today?.status ?? null} />
        {s.today?.inAt && (
          <span className="inline-flex items-center gap-1.5 font-display text-sm font-semibold tabular-nums">
            {s.today.inAt}
            {s.today.outAt && <span className="text-muted-foreground"> → {s.today.outAt}</span>}
          </span>
        )}
      </div>
      {s.today && <p className="mt-3 text-xs text-muted-foreground">{t(`enums.attendanceSource.${s.today.source}`)}</p>}
    </SectionCard>
  );
}

export function StudentModeCard({ student: s }: { student: StudentDetail }) {
  const { t, formatDate } = useI18n();
  const active = s.exceptions.filter((e) => !e.revokedAt);
  return (
    <SectionCard icon={<Smartphone />} title={t('students.detail.schoolMode')}>
      <p className={LABEL}>{t('students.detail.deviceState')}</p>
      <div className="mt-2 flex items-center justify-between gap-3">
        {s.deviceState && <DeviceModeBadge status={s.deviceState.status} />}
        {s.deviceState?.lastSeenAt && (
          <span className="text-xs text-muted-foreground">{t('students.detail.lastSeen', { time: formatDate(s.deviceState.lastSeenAt, 'HH:mm') })}</span>
        )}
      </div>
      <p className={cn(LABEL, 'mb-2 mt-5')}>{t('students.detail.exceptions')}</p>
      {active.length === 0 ? (
        <p className="text-sm text-muted-foreground">{t('students.detail.noExceptions')}</p>
      ) : (
        <ul className="space-y-2">
          {active.map((e) => (
            <li key={e.id} className={cn('p-3 text-sm', INNER_TILE)}>
              <p className="flex items-center gap-2 font-medium tabular-nums">
                <Timer className="h-4 w-4 text-primary" />
                {formatDate(e.from, 'HH:mm')} – {formatDate(e.until, 'HH:mm')}
              </p>
              <p className="mt-1 text-muted-foreground">{e.reason}</p>
            </li>
          ))}
        </ul>
      )}
    </SectionCard>
  );
}

export function StudentPrivacyNote() {
  const { t } = useI18n();
  return (
    <p className={cn('flex items-start gap-2.5 p-4 text-xs leading-relaxed text-muted-foreground', INNER_TILE)}>
      <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
      {t('students.detail.privacyNote')}
    </p>
  );
}

export function PsychologistNote() {
  const { t } = useI18n();
  return (
    <div className="mb-6 flex items-start gap-3 rounded-2xl bg-info/[0.07] p-4 text-sm ring-1 ring-inset ring-info/25">
      <Lock className="mt-0.5 h-4 w-4 shrink-0 text-info" />
      {t('students.detail.psychologistNote')}
    </div>
  );
}
