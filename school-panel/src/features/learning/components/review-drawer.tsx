'use client';

import { Check, MessageSquareText, SkipForward, Undo2 } from 'lucide-react';
import { useRef, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Sheet, SheetContent, SheetDescription, SheetFooter, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { Textarea } from '@/components/ui/textarea';
import type { HomeworkSubmission, StudentSubmissionRow } from '@/data/contracts';
import { REVIEW_NOTE_MAX } from '@/data/schemas/learning';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useReviewSubmission } from '../hooks';
import { nextPendingStudentId, reviewNoteError, stateOf, toReviewBody } from '../lib/submissions';
import { PhotoGallery } from './photo-gallery';
import { SubmissionStatusChip } from './submission-status';

type Props = {
  assignmentId: string;
  /** Tanlangan o'quvchi qatori (jonli ma'lumotdan) — `null` bo'lsa panel yopiq. */
  row: StudentSubmissionRow | null;
  rows: readonly StudentSubmissionRow[];
  className: string;
  canReview: boolean;
  onClose: () => void;
  onSelectStudent: (studentId: string) => void;
  onReload: () => void;
};

/**
 * Ishni tekshirish paneli: rasmlar (kattalashtirish bilan), bolaning izohi va qaror — qabul qilish yoki
 * izoh bilan qaytarish. Natija jadvalda darhol ko'rinadi; xatoda avvalgi holatga qaytadi.
 */
export function ReviewDrawer({ assignmentId, row, rows, className, canReview, onClose, onSelectStudent, onReload }: Props) {
  const { t, formatDate } = useI18n();
  const submission = row?.submission ?? null;
  return (
    <Sheet open={row !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="w-[calc(100%-1rem)] overflow-y-auto sm:max-w-lg">
        <SheetHeader>
          <SheetTitle className="pr-8">{row?.student.fullName ?? ''}</SheetTitle>
          <SheetDescription asChild>
            <div className="flex flex-wrap items-center gap-2 pt-1">
              {row && <SubmissionStatusChip state={stateOf(row)} />}
              <span>{t('learning.submissions.drawer.classLine', { class: className })}</span>
              {submission && <span className="tabular-nums">· {t('learning.submissions.drawer.sentAt', { date: formatDate(submission.submittedAt, 'd MMM, HH:mm') })}</span>}
            </div>
          </SheetDescription>
        </SheetHeader>
        {row && submission && (
          <ReviewBody
            assignmentId={assignmentId}
            studentName={row.student.fullName}
            submission={submission}
            rows={rows}
            studentId={row.student.id}
            canReview={canReview}
            onSelectStudent={onSelectStudent}
            onReload={onReload}
          />
        )}
        {row && !submission && <p className="p-6 text-sm text-muted-foreground">{t('learning.submissions.drawer.notSubmitted')}</p>}
      </SheetContent>
    </Sheet>
  );
}

function ReviewBody({
  assignmentId,
  studentName,
  studentId,
  submission,
  rows,
  canReview,
  onSelectStudent,
  onReload,
}: {
  assignmentId: string;
  studentName: string;
  studentId: string;
  submission: HomeworkSubmission;
  rows: readonly StudentSubmissionRow[];
  canReview: boolean;
  onSelectStudent: (studentId: string) => void;
  onReload: () => void;
}) {
  const { t, formatDate } = useI18n();
  const review = useReviewSubmission(assignmentId);
  const [note, setNote] = useState(submission.reviewNote ?? '');
  const [showNoteError, setShowNoteError] = useState(false);
  // O'quvchi almashganda izoh tozalanadi — lekin panelni qayta yaratmaymiz: «Keyingi ish» tugmasida fokus qoladi.
  const [shownStudentId, setShownStudentId] = useState(studentId);
  if (shownStudentId !== studentId) {
    setShownStudentId(studentId);
    setNote(submission.reviewNote ?? '');
    setShowNoteError(false);
  }
  const noteRef = useRef<HTMLTextAreaElement>(null);
  const [pendingStatus, setPendingStatus] = useState<'ACCEPTED' | 'RETURNED' | null>(null);

  const noteError = reviewNoteError('RETURNED', note);
  const nextId = nextPendingStudentId(rows, studentId);

  const decide = (status: 'ACCEPTED' | 'RETURNED') => {
    if (reviewNoteError(status, note)) {
      setShowNoteError(true);
      noteRef.current?.focus();
      return;
    }
    setShowNoteError(false);
    setPendingStatus(status);
    review.mutate({ submissionId: submission.id, review: toReviewBody(status, note) }, { onSettled: () => setPendingStatus(null) });
  };

  const errorText = showNoteError && noteError ? t(noteError === 'required' ? 'learning.submissions.drawer.noteRequired' : 'errors.form.tooLong', { max: REVIEW_NOTE_MAX }) : null;

  return (
    <>
      <div className="space-y-6 p-6">
        <section aria-labelledby="rv-photos" className="space-y-3">
          <h3 id="rv-photos" className="text-2xs font-semibold uppercase tracking-wider text-muted-foreground">
            {t('learning.submissions.drawer.photos')}
          </h3>
          {submission.photos.length > 0 ? (
            <PhotoGallery photos={submission.photos} studentName={studentName} onReload={onReload} />
          ) : (
            <p className="text-sm text-muted-foreground">{t('learning.submissions.drawer.noPhotos')}</p>
          )}
        </section>

        <section aria-labelledby="rv-comment" className="space-y-2">
          <h3 id="rv-comment" className="text-2xs font-semibold uppercase tracking-wider text-muted-foreground">
            {t('learning.submissions.drawer.childComment')}
          </h3>
          <p className={cn('flex gap-2 rounded-xl bg-white/50 p-3 text-sm ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]', !submission.comment && 'text-muted-foreground')}>
            <MessageSquareText className="mt-0.5 h-4 w-4 shrink-0 text-primary" aria-hidden />
            <span className="whitespace-pre-line">{submission.comment || t('learning.submissions.drawer.noComment')}</span>
          </p>
        </section>

        {submission.reviewedAt && (
          <p className="text-xs text-muted-foreground tabular-nums">{t('learning.submissions.drawer.reviewed', { date: formatDate(submission.reviewedAt, 'd MMM, HH:mm') })}</p>
        )}

        {canReview ? (
          <div className="space-y-1.5">
            <Label htmlFor="rv-note">{t('learning.submissions.drawer.noteLabel')}</Label>
            <Textarea
              id="rv-note"
              ref={noteRef}
              value={note}
              rows={3}
              onChange={(e) => setNote(e.target.value)}
              placeholder={t('learning.submissions.drawer.notePlaceholder')}
              aria-invalid={errorText ? true : undefined}
              aria-describedby="rv-note-hint"
            />
            <div id="rv-note-hint" className="flex items-start justify-between gap-3 text-2xs">
              <span className={errorText ? 'font-medium text-destructive' : 'text-muted-foreground'} role={errorText ? 'alert' : undefined}>
                {errorText ?? t('learning.submissions.drawer.noteReturnHint')}
              </span>
              <span className={cn('shrink-0 tabular-nums', note.trim().length > REVIEW_NOTE_MAX ? 'font-semibold text-destructive' : 'text-muted-foreground')}>
                {t('learning.submissions.drawer.noteChars', { count: note.trim().length, max: REVIEW_NOTE_MAX })}
              </span>
            </div>
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">{t('learning.submissions.drawer.readOnly')}</p>
        )}
      </div>

      <SheetFooter className="sticky bottom-0 flex-wrap gap-2 bg-background/80 backdrop-blur-md sm:justify-between">
        <Button type="button" variant="ghost" disabled={!nextId} onClick={() => nextId && onSelectStudent(nextId)}>
          <SkipForward />
          {t('learning.submissions.drawer.next')}
        </Button>
        {canReview && (
          <div className="flex flex-wrap gap-2">
            <Button type="button" variant="outline" disabled={review.isPending} loading={pendingStatus === 'RETURNED'} onClick={() => decide('RETURNED')}>
              <Undo2 />
              {t('learning.submissions.drawer.return')}
            </Button>
            <Button type="button" disabled={review.isPending} loading={pendingStatus === 'ACCEPTED'} onClick={() => decide('ACCEPTED')}>
              <Check />
              {t('learning.submissions.drawer.accept')}
            </Button>
          </div>
        )}
      </SheetFooter>
    </>
  );
}
