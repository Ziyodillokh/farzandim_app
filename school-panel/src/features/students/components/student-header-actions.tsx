'use client';

import { Archive, ArchiveRestore, LogOut, MessageSquareText, MoreHorizontal, Pencil, ShieldOff } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import type { StudentDetail } from '@/data/mock/services/students';
import { EarlyExitDialog } from '@/features/attendance/components/early-exit-dialog';
import { ExceptionDialog } from '@/features/school-mode/components/exception-dialog';
import { useI18n } from '@/i18n';
import { useArchiveStudent } from '../hooks';
import { StudentFormDialog } from './student-form-dialog';

type Dialog = 'earlyExit' | 'exception' | 'edit' | 'archive' | null;

/** Ota-onalarga xabar havolasi: `/messages/new?guardianId=g1,g2` (auditoriya oldindan tanlanadi). */
export function messageParentsHref(guardianIds: readonly string[]): string {
  return `/messages/new?guardianId=${guardianIds.map(encodeURIComponent).join(',')}`;
}

/**
 * Karta sarlavhasidagi amallar — har biri faqat o'z ruxsati bilan:
 * xabar (`messages.send*`), erta ketish (`attendance.earlyExit`),
 * School Mode istisnosi (`schoolMode.exception`), tahrirlash/arxiv (`students.manage`).
 */
export function StudentHeaderActions({ student: s }: { student: StudentDetail }) {
  const { t } = useI18n();
  const can = useCan();
  const archive = useArchiveStudent();
  const [dialog, setDialog] = useState<Dialog>(null);
  const close = (open: boolean) => !open && setDialog(null);

  const canMessage = (can('messages.sendClass') || can('messages.sendSchool')) && s.guardians.length > 0;
  const active = !s.archived;

  const toggleArchive = async () => {
    try {
      await archive.mutateAsync({ id: s.id, archived: !s.archived });
      setDialog(null);
    } catch {
      // Xato toast orqali ko'rsatildi (useStudentMutation.onError).
    }
  };

  return (
    <>
      {canMessage && (
        <Button asChild variant="soft">
          <Link href={messageParentsHref(s.guardians.map((g) => g.id))}>
            <MessageSquareText />
            {t('students.actions.messageParents')}
          </Link>
        </Button>
      )}
      {active && can('attendance.earlyExit') && (
        <Button variant="outline" onClick={() => setDialog('earlyExit')}>
          <LogOut />
          {t('students.actions.earlyExit')}
        </Button>
      )}
      {active && can('schoolMode.exception') && (
        <Button variant="outline" onClick={() => setDialog('exception')}>
          <ShieldOff />
          {t('students.actions.exception')}
        </Button>
      )}
      {can('students.manage') && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="outline" size="icon" aria-label={t('students.actions.more')} title={t('students.actions.more')}>
              <MoreHorizontal />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={() => setDialog('edit')}>
              <Pencil className="h-4 w-4" />
              {t('common.edit')}
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => setDialog('archive')}>
              {s.archived ? <ArchiveRestore className="h-4 w-4" /> : <Archive className="h-4 w-4" />}
              {s.archived ? t('students.restore') : t('students.archive')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      )}

      {can('attendance.earlyExit') && <EarlyExitDialog open={dialog === 'earlyExit'} onOpenChange={close} defaultStudent={s} />}
      {can('schoolMode.exception') && <ExceptionDialog open={dialog === 'exception'} onOpenChange={close} defaultStudent={s} />}
      {can('students.manage') && <StudentFormDialog open={dialog === 'edit'} onOpenChange={close} student={s} />}
      <ConfirmDialog
        open={dialog === 'archive'}
        onOpenChange={close}
        title={s.archived ? t('students.restore') : t('students.archive')}
        description={s.archived ? undefined : t('students.archiveConfirm', { name: `${s.lastName} ${s.firstName}` })}
        destructive={!s.archived}
        loading={archive.isPending}
        onConfirm={() => void toggleArchive()}
      />
    </>
  );
}
