'use client';

/**
 * "Yangi savol" — `POST /admin/kelajak/questions`.
 * Javob turi tanlanganda standart variantlar (JSON `answer_scales`) to'ldiriladi.
 */

import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Loader2 } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { kelajakApi, type KelajakQuestionCreatePayload } from '@/lib/api/admin.api';
import { getApiErrorCode, kelajakErrorMessage } from './kelajak-errors';
import { kelajakKeys } from './kelajak-keys';
import { QuestionFormFields } from './question-form-fields';
import {
  emptyForm,
  hasErrors,
  toCreatePayload,
  validateForm,
  type FormErrors,
} from './question-form';

interface CreateDefaults {
  category?: string;
  ageGroup?: string;
}

export function QuestionCreateDialog({
  open,
  onOpenChange,
  defaults,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  /** Joriy filtrdagi kategoriya/yosh — forma shular bilan boshlanadi. */
  defaults: CreateDefaults;
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="flex max-h-[92vh] w-[calc(100vw-1.5rem)] max-w-3xl flex-col gap-0 p-0">
        {open && <CreateBody defaults={defaults} onClose={() => onOpenChange(false)} />}
      </DialogContent>
    </Dialog>
  );
}

function CreateBody({ defaults, onClose }: { defaults: CreateDefaults; onClose: () => void }) {
  const qc = useQueryClient();
  const [form, setForm] = useState(() => emptyForm(defaults));
  const [submitted, setSubmitted] = useState(false);
  // Backend band deb qaytargan ID — admin uni o'zgartirguncha xato ko'rinib turadi.
  const [rejectedId, setRejectedId] = useState<string | null>(null);

  const errors = validateForm(form, 'create');
  const isDuplicate = rejectedId !== null && form.externalId.trim() === rejectedId;
  const shownErrors: FormErrors = {
    ...(submitted ? errors : {}),
    ...(isDuplicate ? { externalId: 'Bu ID band — boshqasini kiriting yoki bo‘sh qoldiring.' } : {}),
  };

  const create = useMutation({
    mutationFn: (payload: KelajakQuestionCreatePayload) => kelajakApi.create(payload),
    onSuccess: (created) => {
      toast.success(created?.externalId ? `Savol yaratildi: ${created.externalId}` : 'Savol yaratildi');
      void qc.invalidateQueries({ queryKey: kelajakKeys.all });
      onClose();
    },
    onError: (e, payload) => {
      if (getApiErrorCode(e) === 'DUPLICATE_EXTERNAL_ID' && payload.externalId) {
        setRejectedId(payload.externalId);
      }
      toast.error(kelajakErrorMessage(e));
    },
  });

  const handleCreate = () => {
    setSubmitted(true);
    if (hasErrors(errors)) {
      toast.error('Formadagi xatolarni tuzating');
      return;
    }
    create.mutate(toCreatePayload(form));
  };

  return (
    <>
      <DialogHeader className="border-b border-border px-4 pb-4 pt-5 pr-12 sm:px-6">
        <DialogTitle>Yangi savol</DialogTitle>
        <DialogDescription>
          Savol faqat tanlangan yosh guruhidagi bolalarga beriladi. Manba maydonlarini backend belgilaydi.
        </DialogDescription>
      </DialogHeader>

      <div className="flex-1 overflow-y-auto px-4 py-5 sm:px-6">
        <QuestionFormFields
          form={form}
          setForm={setForm}
          errors={shownErrors}
          mode="create"
          locked={false}
        />
      </div>

      <div className="flex flex-wrap items-center justify-end gap-2 border-t border-border px-4 py-3 sm:px-6">
        <Button variant="ghost" onClick={onClose}>
          Bekor qilish
        </Button>
        <Button onClick={handleCreate} disabled={create.isPending}>
          {create.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
          Yaratish
        </Button>
      </div>
    </>
  );
}
