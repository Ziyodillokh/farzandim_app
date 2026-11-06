'use client';

import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { useCan } from '@/auth/use-session';
import type { StudentDetail } from '@/data/mock/services/students';
import { studentKeys } from '@/features/students/hooks';
import { markNotLinked } from '../hooks';
import { useFocusReturn } from '../lib/use-focus-return';
import { CredentialsCard } from './credentials-card';
import { CredentialsDialog, type CredentialsMode } from './credentials-dialog';
import { InviteCodeCard } from './invite-code-card';
import { RecoveryCard } from './recovery-card';

/**
 * O'quvchi kartasi «Kirish» tabi: parol tiklash so'rovlari (bo'lsa, tepada), taklif kodi (`guardians.link`)
 * va kirish ma'lumotlari (`students.manage`). Kirish ma'lumotlari oynasi shu yerda: tiklash so'rovidan ham, kartadan ham ochiladi.
 */
export function AccessPanel({ student }: { student: StudentDetail }) {
  const can = useCan();
  const queryClient = useQueryClient();
  const [dialog, setDialog] = useState<CredentialsMode | null>(null);
  const focus = useFocusReturn();
  const openDialog = (mode: CredentialsMode) => {
    focus.remember();
    setDialog(mode);
  };
  const canManage = can('students.manage');
  const canLink = can('guardians.link');
  const name = `${student.lastName} ${student.firstName}`;
  // Arxivdagi o'quvchi: ma'lumot o'qiladi, yangi kod / kirish ma'lumoti berilmaydi (backend `409`).
  const archived = student.archived;

  return (
    <div className="space-y-6">
      {canManage && <RecoveryCard studentId={student.id} archived={archived} onReset={() => openDialog('reset')} />}
      <div className="grid items-start gap-6 lg:grid-cols-2">
        {canLink && <InviteCodeCard studentId={student.id} studentName={name} className={student.className} archived={archived} />}
        {canManage && <CredentialsCard studentId={student.id} archived={archived} onIssue={() => openDialog('issue')} onReset={() => openDialog('reset')} />}
      </div>
      {dialog && (
        <CredentialsDialog
          studentId={student.id}
          studentName={name}
          className={student.className}
          mode={dialog}
          onClose={() => setDialog(null)}
          onCloseAutoFocus={focus.restore}
          onNotLinked={() => markNotLinked(queryClient, student.id)}
          // Karta eskirgan: o'quvchi arxivga olingan — ko'rinish yangilanadi, berish/tiklash tugmalari yo'qoladi.
          onArchived={() => void queryClient.invalidateQueries({ queryKey: studentKeys.all })}
        />
      )}
    </div>
  );
}
