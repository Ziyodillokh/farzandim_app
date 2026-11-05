'use client';

/**
 * Mavzu yaratish / tahrirlash — `POST /admin/learning/topics`,
 * `PATCH /admin/learning/topics/:id`.
 *
 * Tahrirlashda faqat o'zgargan maydonlar yuboriladi; fan o'zgarmaydi.
 * Kalit shu fanda band bo'lsa (409) xato kalit maydonida ko'rsatiladi va
 * admin kalitni o'zgartirguncha saqlanib turadi.
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
import { learningTopicsApi } from '@/lib/api/admin.api';
import type { LearningSubject, LearningTopic } from '@/types/api.types';
import { KEY_CONFLICT_MESSAGE, isKeyConflict, topicErrorMessage } from './topic-errors';
import { learningKeys } from './topic-keys';
import {
  emptyTopicForm,
  formFromTopic,
  hasTopicFormErrors,
  toTopicCreatePayload,
  toTopicPatchPayload,
  validateTopicForm,
  type TopicFormErrors,
} from './topic-form';
import { TopicFormFields } from './topic-form-fields';

export type TopicFormTarget =
  | { mode: 'create'; subject: LearningSubject }
  | { mode: 'edit'; topic: LearningTopic };

export function TopicFormDialog({
  target,
  onOpenChange,
}: {
  /** `null` — oyna yopiq. */
  target: TopicFormTarget | null;
  onOpenChange: (open: boolean) => void;
}) {
  return (
    <Dialog open={target !== null} onOpenChange={onOpenChange}>
      <DialogContent className="flex max-h-[92vh] w-[calc(100vw-1.5rem)] max-w-2xl flex-col gap-0 p-0">
        {/* key — boshqa mavzu ochilsa forma noldan to'ldiriladi */}
        {target && (
          <FormBody
            key={target.mode === 'edit' ? target.topic.id : 'create'}
            target={target}
            onClose={() => onOpenChange(false)}
          />
        )}
      </DialogContent>
    </Dialog>
  );
}

function FormBody({ target, onClose }: { target: TopicFormTarget; onClose: () => void }) {
  const qc = useQueryClient();
  const isEdit = target.mode === 'edit';
  const [form, setForm] = useState(() =>
    target.mode === 'edit' ? formFromTopic(target.topic) : emptyTopicForm(target.subject),
  );
  const [submitted, setSubmitted] = useState(false);
  // Backend band deb qaytargan kalit — admin uni o'zgartirguncha xato ko'rinib turadi.
  const [rejectedKey, setRejectedKey] = useState<string | null>(null);

  const errors = validateTopicForm(form, target.mode);
  const isKeyRejected = rejectedKey !== null && form.key.trim() === rejectedKey;
  const shownErrors: TopicFormErrors = {
    ...(submitted ? errors : {}),
    ...(isKeyRejected ? { key: KEY_CONFLICT_MESSAGE } : {}),
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
        setRejectedKey(form.key.trim());
        toast.error(KEY_CONFLICT_MESSAGE);
        return;
      }
      toast.error(topicErrorMessage(err));
    },
  });

  const handleSave = () => {
    setSubmitted(true);
    if (hasTopicFormErrors(errors)) {
      toast.error('Formadagi xatolarni tuzating');
      return;
    }
    if (isKeyRejected) return;
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
          <TopicFormFields form={form} setForm={setForm} errors={shownErrors} mode={target.mode} />
        </div>

        <div className="flex flex-wrap items-center justify-end gap-2 border-t border-border px-4 py-3 sm:px-6">
          <Button type="button" variant="ghost" onClick={onClose}>
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
