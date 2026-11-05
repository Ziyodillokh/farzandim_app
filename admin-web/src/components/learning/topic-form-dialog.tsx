'use client';

/**
 * Mavzu yaratish / tahrirlash — `POST /admin/learning/topics`,
 * `PATCH /admin/learning/topics/:id`.
 *
 * Tahrirlashda faqat o'zgargan maydonlar yuboriladi; fan o'zgarmaydi.
 * Kalit shu fanda band bo'lsa (409) xato kalit maydonida ko'rsatiladi va
 * admin kalitni o'zgartirguncha saqlanib turadi.
 */

import { useEffect, useState } from 'react';
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
import { learningTopicsApi } from '@/lib/api/admin.api';
import type { LearningSubject, LearningTopic } from '@/types/api.types';
import { KEY_CONFLICT_MESSAGE, isKeyConflict, topicErrorMessage } from './topic-errors';
import { learningKeys } from './topic-keys';
import {
  emptyTopicForm,
  formFromTopic,
  hasTopicFormErrors,
  isKeyRejected,
  toTopicCreatePayload,
  toTopicPatchPayload,
  validateTopicForm,
  type RejectedKey,
  type TopicFormErrors,
} from './topic-form';
import { TopicFormFields } from './topic-form-fields';

export type TopicFormTarget =
  | { mode: 'create'; subject: LearningSubject }
  | { mode: 'edit'; topic: LearningTopic };

export function TopicFormDialog({
  target,
  onOpenChange,
  onCloseAutoFocus,
}: {
  /** `null` — oyna yopiq. */
  target: TopicFormTarget | null;
  onOpenChange: (open: boolean) => void;
  /** Oyna yopilganda fokusni ochgan tugmaga qaytarish uchun. */
  onCloseAutoFocus?: (event: Event) => void;
}) {
  // Saqlash ketayotganda oyna yopilmaydi (Esc, tashqariga bosish, "×") —
  // aks holda natija (xato yoki muvaffaqiyat) ko'rinmay qoladi.
  const [isSaving, setIsSaving] = useState(false);
  const handleOpenChange = (open: boolean) => {
    if (!open && isSaving) return;
    onOpenChange(open);
  };

  return (
    <Dialog open={target !== null} onOpenChange={handleOpenChange}>
      <DialogContent
        className="flex max-h-[92vh] w-[calc(100vw-1.5rem)] max-w-2xl flex-col gap-0 p-0"
        onCloseAutoFocus={onCloseAutoFocus}
      >
        {/* key — boshqa mavzu ochilsa forma noldan to'ldiriladi */}
        {target && (
          <FormBody
            key={target.mode === 'edit' ? target.topic.id : 'create'}
            target={target}
            onSavingChange={setIsSaving}
            onClose={() => onOpenChange(false)}
          />
        )}
      </DialogContent>
    </Dialog>
  );
}

function FormBody({
  target,
  onClose,
  onSavingChange,
}: {
  target: TopicFormTarget;
  onClose: () => void;
  onSavingChange: (isSaving: boolean) => void;
}) {
  const qc = useQueryClient();
  const isEdit = target.mode === 'edit';
  const [form, setForm] = useState(() =>
    target.mode === 'edit' ? formFromTopic(target.topic) : emptyTopicForm(target.subject),
  );
  const [submitted, setSubmitted] = useState(false);
  // Backend band deb qaytargan fan + kalit — admin ikkalasidan birini o'zgartirguncha xato ko'rinib turadi.
  const [rejectedKey, setRejectedKey] = useState<RejectedKey | null>(null);

  const errors = validateTopicForm(form, target.mode);
  const keyIsRejected = isKeyRejected(rejectedKey, form);
  const shownErrors: TopicFormErrors = {
    ...(submitted ? errors : {}),
    ...(keyIsRejected ? { key: KEY_CONFLICT_MESSAGE } : {}),
  };

  const save = useMutation({
    mutationFn: async () => {
      if (target.mode === 'create') {
        return learningTopicsApi.create(toTopicCreatePayload(form));
      }
      return learningTopicsApi.update(target.topic.id, toTopicPatchPayload(form, target.topic));
    },
    onSuccess: (saved) => {
      toast.success(isEdit ? 'Mavzu saqlandi' : `Mavzu yaratildi: ${saved.title.uz}`);
      void qc.invalidateQueries({ queryKey: learningKeys.topics });
      onClose();
    },
    onError: (err) => {
      if (isKeyConflict(err)) {
        setRejectedKey({ subject: form.subject, key: form.key.trim() });
        toast.error(KEY_CONFLICT_MESSAGE);
        return;
      }
      toast.error(topicErrorMessage(err));
    },
  });

  // Ota-ona oynasi saqlash tugamaguncha yopilishni to'xtatadi.
  useEffect(() => {
    onSavingChange(save.isPending);
    return () => onSavingChange(false);
  }, [save.isPending, onSavingChange]);

  const handleSave = () => {
    setSubmitted(true);
    if (hasTopicFormErrors(errors)) {
      toast.error('Formadagi xatolarni tuzating');
      return;
    }
    if (keyIsRejected) return;
    if (target.mode === 'edit' && Object.keys(toTopicPatchPayload(form, target.topic)).length === 0) {
      toast.info("O'zgarish yo'q");
      onClose();
      return;
    }
    save.mutate();
  };

  return (
    <>
      <DialogHeader className="border-b border-border px-4 pb-4 pt-5 pr-12 sm:px-6">
        <DialogTitle>{isEdit ? 'Mavzuni tahrirlash' : 'Yangi mavzu'}</DialogTitle>
        <DialogDescription>
          Mavzu — bola ilovasidagi fan yo&apos;lining bir bosqichi. Savollarni mavzu yaratilgandan
          keyin &quot;Savollar&quot; orqali biriktirasiz.
        </DialogDescription>
      </DialogHeader>

      {/* <form> — Enter bilan ham saqlanadi */}
      <form
        noValidate
        className="flex min-h-0 flex-1 flex-col"
        onSubmit={(e) => {
          e.preventDefault();
          handleSave();
        }}
      >
        <div className="flex-1 overflow-y-auto px-4 py-5 sm:px-6">
          {/* Saqlash ketayotganda maydonlar qulflanadi: yuborilgan qiymat o'zgarib ketmasin. */}
          <fieldset disabled={save.isPending} className="min-w-0">
            <TopicFormFields form={form} setForm={setForm} errors={shownErrors} mode={target.mode} />
          </fieldset>
        </div>

        <div className="flex flex-wrap items-center justify-end gap-2 border-t border-border px-4 py-3 sm:px-6">
          <Button type="button" variant="ghost" disabled={save.isPending} onClick={onClose}>
            Bekor qilish
          </Button>
          <Button type="submit" disabled={save.isPending}>
            {save.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
            {isEdit ? 'Saqlash' : 'Yaratish'}
          </Button>
        </div>
      </form>
    </>
  );
}
