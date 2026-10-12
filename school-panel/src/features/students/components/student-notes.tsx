'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { NotebookPen, Save, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { useForm } from 'react-hook-form';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { FormField } from '@/components/common/form-field';
import { SectionCard } from '@/components/common/section-card';
import { StaffAvatar } from '@/components/common/staff-avatar';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Textarea } from '@/components/ui/textarea';
import type { StudentNoteRow } from '@/data/mock/services/student-360';
import { STUDENT_NOTE_MAX, studentNoteSchema, type StudentNoteInput } from '@/data/schemas/students';
import { INNER_TILE } from '@/features/classes/styles';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useAddStudentNote, useDeleteStudentNote, useStudentNotes } from '../hooks';

function NoteForm({ studentId }: { studentId: string }) {
  const { t } = useI18n();
  const add = useAddStudentNote();
  const form = useForm<StudentNoteInput>({ resolver: zodResolver(studentNoteSchema), defaultValues: { text: '' } });
  const length = (form.watch('text') ?? '').length;
  const over = length > STUDENT_NOTE_MAX;
  const error = form.formState.errors.text;

  const submit = form.handleSubmit(async ({ text }) => {
    try {
      await add.mutateAsync({ studentId, text });
      form.reset({ text: '' });
    } catch {
      // Xato toast orqali ko'rsatildi (useStudentMutation.onError).
    }
  });

  return (
    <form onSubmit={(e) => void submit(e)} noValidate className="space-y-2">
      <FormField
        label={t('students.notes.label')}
        htmlFor="student-note"
        error={error?.message === 'errors.form.tooLong' ? { message: t('errors.form.tooLong', { max: STUDENT_NOTE_MAX }) } : error}
      >
        <Textarea id="student-note" rows={3} placeholder={t('students.notes.placeholder')} aria-invalid={Boolean(error) || over} {...form.register('text')} />
      </FormField>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <span className={cn('text-2xs tabular-nums text-muted-foreground', over && 'font-semibold text-destructive')}>
          {t('students.notes.counter', { count: length, max: STUDENT_NOTE_MAX })}
        </span>
        <Button type="submit" size="sm" loading={add.isPending} disabled={length === 0 || over}>
          <Save />
          {t('students.notes.add')}
        </Button>
      </div>
    </form>
  );
}

function NoteItem({ note, onDelete }: { note: StudentNoteRow; onDelete: (note: StudentNoteRow) => void }) {
  const { t, formatDate, formatRelative } = useI18n();
  return (
    <li className={cn('p-4', INNER_TILE)}>
      <div className="flex items-start gap-3">
        <StaffAvatar staffId={note.byStaffId} name={note.byName} size="sm" />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-0.5">
            <p className="truncate text-sm font-semibold">{note.byName}</p>
            <time dateTime={note.at} title={formatDate(note.at, 'd MMMM yyyy, HH:mm')} className="text-xs text-muted-foreground">
              {formatRelative(note.at)}
            </time>
          </div>
          <p className="mt-1.5 whitespace-pre-wrap break-words text-sm leading-relaxed">{note.text}</p>
        </div>
        {note.canDelete && (
          <Button type="button" variant="ghost" size="icon-sm" onClick={() => onDelete(note)} aria-label={t('students.notes.delete')} title={t('students.notes.delete')}>
            <Trash2 />
          </Button>
        )}
      </div>
    </li>
  );
}

/** Xodim eslatmalari: qo'shish (1–1000 belgi), ro'yxat, muallif yoki direktor/admin o'chiradi. */
export function StudentNotes({ studentId }: { studentId: string }) {
  const { t } = useI18n();
  const notes = useStudentNotes(studentId);
  const remove = useDeleteStudentNote();
  const [pending, setPending] = useState<StudentNoteRow | null>(null);

  const confirmDelete = async () => {
    if (!pending) return;
    try {
      await remove.mutateAsync(pending.id);
      setPending(null);
    } catch {
      // Xato toast orqali ko'rsatildi.
    }
  };

  return (
    <SectionCard icon={<NotebookPen />} title={t('students.notes.title')} description={t('students.notes.description')}>
      <NoteForm studentId={studentId} />
      <div className="mt-6">
        {notes.isError ? (
          <ErrorState error={notes.error} onRetry={() => void notes.refetch()} />
        ) : !notes.data ? (
          <div className="space-y-3">
            <Skeleton className="h-20 w-full rounded-xl" />
            <Skeleton className="h-20 w-full rounded-xl" />
          </div>
        ) : notes.data.length === 0 ? (
          <EmptyState icon={<NotebookPen />} title={t('students.notes.empty')} description={t('students.notes.emptyHint')} className="py-8" />
        ) : (
          <ul className="space-y-3">
            {notes.data.map((note) => (
              <NoteItem key={note.id} note={note} onDelete={setPending} />
            ))}
          </ul>
        )}
      </div>
      <ConfirmDialog
        open={pending !== null}
        onOpenChange={(open) => !open && setPending(null)}
        title={t('students.notes.deleteTitle')}
        description={t('students.notes.deleteText')}
        confirmLabel={t('common.delete')}
        destructive
        loading={remove.isPending}
        onConfirm={() => void confirmDelete()}
      />
    </SectionCard>
  );
}
