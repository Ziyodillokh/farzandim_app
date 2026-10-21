'use client';

/**
 * Savolni ko'rish/tahrirlash — `GET/PATCH /admin/kelajak/questions/:id`.
 *
 * Ochilganda detal qayta so'raladi: `answerCount` eng so'nggi bo'lsin
 * (bloklash shunga bog'liq). Admin hali tegmagan bo'lsa forma eng so'nggi
 * server qiymatidan qayta to'ldiriladi; PATCH esa faqat admin O'ZI
 * o'zgartirgan maydonlarni (forma to'ldirilgan holatga nisbatan) yuboradi —
 * boshqa admin kiritgan tuzatishlar eskirgan ro'yxat qatori bilan qaytib
 * qolmaydi.
 */

import { useCallback, useEffect, useState, type SetStateAction } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { AlertTriangle, Loader2 } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { kelajakApi } from '@/lib/api/admin.api';
import { ageGroupLabel, answerTypeLabel, categoryLabel } from '@/lib/constants/kelajak';
import type { KelajakQuestion } from '@/types/api.types';
import { getApiErrorCode, kelajakErrorMessage } from './kelajak-errors';
import { kelajakKeys } from './kelajak-keys';
import { LockNotice, QuestionMeta } from './question-meta';
import { QuestionFormFields } from './question-form-fields';
import {
  formFromQuestion,
  hasErrors,
  toPatchPayload,
  validateForm,
  withLockedFrom,
  type QuestionForm,
} from './question-form';

export function QuestionEditDialog({
  question,
  onOpenChange,
}: {
  /** `null` — oyna yopiq. */
  question: KelajakQuestion | null;
  onOpenChange: (v: boolean) => void;
}) {
  return (
    <Dialog open={question !== null} onOpenChange={onOpenChange}>
      <DialogContent className="flex max-h-[92vh] w-[calc(100vw-1.5rem)] max-w-3xl flex-col gap-0 p-0">
        {/* key — boshqa savol ochilsa forma noldan to'ldiriladi */}
        {question && (
          <EditBody key={question.id} initial={question} onClose={() => onOpenChange(false)} />
        )}
      </DialogContent>
    </Dialog>
  );
}

function EditBody({ initial, onClose }: { initial: KelajakQuestion; onClose: () => void }) {
  const qc = useQueryClient();
  const detail = useQuery({
    queryKey: kelajakKeys.detail(initial.id),
    queryFn: () => kelajakApi.detail(initial.id),
    initialData: initial,
    staleTime: 0,
  });
  const question = detail.data;
  const locked = question.answerCount > 0;

  // `base` — forma qaysi server holatidan to'ldirilgan (PATCH shunga nisbatan).
  const [base, setBase] = useState(initial);
  const [form, setFormState] = useState(() => formFromQuestion(initial));
  const [touched, setTouched] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const setForm = useCallback((action: SetStateAction<QuestionForm>) => {
    setTouched(true);
    setFormState(action);
  }, []);

  // Admin hali tegmagan — forma yangi kelgan detaldan qayta to'ldiriladi.
  useEffect(() => {
    if (touched) return;
    setBase(question);
    setFormState(formFromQuestion(question));
  }, [question, touched]);

  // Bloklangan bo'lsa (yoki ochiq turganda bloklansa) bu maydonlar server qiymatida turadi.
  useEffect(() => {
    if (locked) setFormState((prev) => withLockedFrom(prev, question));
  }, [locked, question]);

  const errors = validateForm(form, 'edit');
  const patch = toPatchPayload(form, base, locked);
  const isDirty = Object.keys(patch).length > 0;
  const isStale = touched && question.updatedAt !== base.updatedAt;

  const save = useMutation({
    mutationFn: () => kelajakApi.update(question.id, patch),
    onSuccess: () => {
      toast.success('Saqlandi');
      void qc.invalidateQueries({ queryKey: kelajakKeys.all });
      onClose();
    },
    onError: (e) => {
      toast.error(kelajakErrorMessage(e));
      // Ochiq turganda savolga javob kelgan — bloklash holatini yangilaymiz.
      if (getApiErrorCode(e) === 'QUESTION_IN_USE') {
        void qc.invalidateQueries({ queryKey: kelajakKeys.detail(question.id) });
      }
    },
  });

  const handleSave = () => {
    setSubmitted(true);
    if (hasErrors(errors)) {
      toast.error('Formadagi xatolarni tuzating');
      return;
    }
    save.mutate();
  };

  return (
    <>
      <DialogHeader className="border-b border-border px-4 pb-4 pt-5 pr-12 sm:px-6">
        <DialogTitle className="font-mono text-base">{question.externalId}</DialogTitle>
        <DialogDescription>
          {categoryLabel(question.category)} · {ageGroupLabel(question.ageGroup)} ·{' '}
          {answerTypeLabel(question.answerType)}
        </DialogDescription>
        <div className="flex flex-wrap gap-1.5 pt-1">
          <Badge variant={question.active ? 'success' : 'secondary'} size="sm">
            {question.active ? 'Faol' : 'Nofaol'}
          </Badge>
          {question.reviewNote && (
            <Badge variant="warning" size="sm">
              <AlertTriangle className="h-3 w-3" /> Ko&apos;rib chiqish kerak
            </Badge>
          )}
          {question.reverse && <Badge variant="info" size="sm">Teskari ball</Badge>}
          <Badge variant="outline" size="sm">Javoblar: {question.answerCount}</Badge>
        </div>
      </DialogHeader>

      <div className="flex-1 space-y-6 overflow-y-auto px-4 py-5 sm:px-6">
        {detail.isError && (
          <p role="alert" className="text-xs text-destructive">
            Eng so&apos;nggi ma&apos;lumotni yuklab bo&apos;lmadi: {kelajakErrorMessage(detail.error)}
          </p>
        )}
        {isStale && (
          <p role="status" className="rounded-lg border border-warning/30 bg-warning/10 px-3 py-2 text-xs">
            Savol shu orada boshqa joyda yangilangan. Saqlash faqat siz o&apos;zgartirgan maydonlarni yuboradi —
            qolgan yangi qiymatlar saqlanib qoladi.
          </p>
        )}
        {locked && <LockNotice answerCount={question.answerCount} />}
        <QuestionFormFields
          form={form}
          setForm={setForm}
          errors={submitted ? errors : {}}
          mode="edit"
          locked={locked}
        />
        <QuestionMeta question={question} />
      </div>

      <div className="flex flex-wrap items-center justify-end gap-2 border-t border-border px-4 py-3 sm:px-6">
        {!isDirty && <span className="mr-auto text-xs text-muted-foreground">O&apos;zgarish yo&apos;q</span>}
        <Button variant="ghost" onClick={onClose}>
          Bekor qilish
        </Button>
        <Button onClick={handleSave} disabled={!isDirty || save.isPending}>
          {save.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
          Saqlash
        </Button>
      </div>
    </>
  );
}
