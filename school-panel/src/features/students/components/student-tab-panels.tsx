'use client';

import { CalendarDays } from 'lucide-react';

import { SectionCard } from '@/components/common/section-card';
import { clockToday } from '@/data/mock/clock';
import type { StudentDetail } from '@/data/mock/services/students';
import { useI18n } from '@/i18n';
import { AttendanceCalendar } from './attendance-calendar';
import { GuardiansCard } from './guardians-card';
import { StudentProfileCard } from './student-profile-card';
import { PsychologistNote, StudentModeCard, StudentPrivacyNote, StudentTodayCard } from './student-side-cards';

/** Profil: psixolog uchun minimal (ism, sinf, smena, sinf rahbari), qolganlarga — ota-ona va School Mode. */
export function ProfilePanel({ student: s, minimal }: { student: StudentDetail; minimal: boolean }) {
  if (minimal) {
    return (
      <div className="max-w-3xl space-y-6">
        <PsychologistNote />
        <StudentProfileCard student={s} minimal />
      </div>
    );
  }
  return (
    <div className="grid items-start gap-6 lg:grid-cols-3">
      <div className="min-w-0 space-y-6 lg:col-span-2">
        <StudentProfileCard student={s} minimal={false} />
        <GuardiansCard studentId={s.id} guardians={s.guardians} />
      </div>
      <div className="space-y-6">
        <StudentTodayCard student={s} />
        <StudentModeCard student={s} />
        <StudentPrivacyNote />
      </div>
    </div>
  );
}

/** Davomat: bugungi holat va oylik kalendar. */
export function AttendancePanel({ student: s }: { student: StudentDetail }) {
  const { t } = useI18n();
  return (
    <div className="grid items-start gap-6 lg:grid-cols-3">
      <SectionCard icon={<CalendarDays />} title={t('students.detail.calendar')} className="min-w-0 lg:col-span-2">
        <AttendanceCalendar studentId={s.id} initialMonth={clockToday().slice(0, 7)} />
      </SectionCard>
      <StudentTodayCard student={s} />
    </div>
  );
}
