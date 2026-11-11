'use client';

/**
 * "Yangi maktab" — `POST /admin/schools`: maktab, standart smena (08:00–13:25,
 * dushanba–shanba) va direktor hisobi. Sinflar, o'quvchilar va boshqa xodimlarni
 * direktor panelda o'zi qo'shadi.
 */

import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { schoolsApi } from '@/lib/api/admin.api';
import type { ShownCredentials } from './credentials-dialog';
import { FormField } from './form-field';
import {
  emptySchoolForm,
  hasErrors,
  LIMITS,
  suggestSchoolCode,
  toCreatePayload,
  validateSchoolForm,
  type SchoolFormErrors,
  type SchoolFormValues,
} from './school-form';
import { getApiErrorCode, schoolsErrorMessage } from './schools-errors';
import { schoolsKeys } from './schools-keys';

export function SchoolCreateDialog({
  open,
  onOpenChange,
  onCreated,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onCreated: (credentials: ShownCredentials) => void;
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="flex max-h-[92vh] w-[calc(100vw-1.5rem)] max-w-xl flex-col gap-0 p-0">
        {open && <CreateBody onClose={() => onOpenChange(false)} onCreated={onCreated} />}
      </DialogContent>
    </Dialog>
  );
}

function CreateBody({ onClose, onCreated }: { onClose: () => void; onCreated: (c: ShownCredentials) => void }) {
  const qc = useQueryClient();
  const [form, setForm] = useState<SchoolFormValues>(emptySchoolForm);
  // Kod qo'lda o'zgartirilmaguncha nomdan taklif qilinadi.
  const [codeTouched, setCodeTouched] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [takenCode, setTakenCode] = useState<string | null>(null);

  const errors = validateSchoolForm(form);
  const shown: SchoolFormErrors = {
    ...(submitted ? errors : {}),
    ...(takenCode !== null && form.code.trim().toLowerCase() === takenCode
      ? { code: 'Bu kod band — boshqasini kiriting' }
      : {}),
  };

  const set = <K extends keyof SchoolFormValues>(key: K, value: SchoolFormValues[K]) =>
    setForm((prev) => ({
      ...prev,
      [key]: value,
      ...(key === 'name' && !codeTouched ? { code: suggestSchoolCode(value) } : {}),
    }));

  const create = useMutation({
    mutationFn: () => schoolsApi.create(toCreatePayload(form)),
    onSuccess: ({ school, credentials }) => {
      toast.success(`Maktab ochildi: ${school.name}`);
      void qc.invalidateQueries({ queryKey: schoolsKeys.all });
      onClose();
      onCreated({
        ...credentials,
        title: 'Direktor hisobi tayyor',
        schoolName: school.name,
      });
    },
    onError: (e) => {
      if (getApiErrorCode(e) === 'SCHOOL_CODE_TAKEN') setTakenCode(form.code.trim().toLowerCase());
      toast.error(schoolsErrorMessage(e));
    },
  });

  const submit = () => {
    setSubmitted(true);
    if (hasErrors(errors)) {
      toast.error('Formadagi xatolarni tuzating');
      return;
    }
    create.mutate();
  };

  const field = (key: keyof SchoolFormValues) => ({
    id: `school-${key}`,
    value: form[key],
    'aria-invalid': Boolean(shown[key]),
    'aria-describedby': shown[key] ? `school-${key}-error` : undefined,
  });

  return (
    <>
      <DialogHeader className="border-b border-border px-4 pb-4 pt-5 pr-12 sm:px-6">
        <DialogTitle>Yangi maktab</DialogTitle>
        <DialogDescription>
          Maktab va uning direktori yaratiladi. Sinflar, o&apos;quvchilar, o&apos;qituvchilar va boshqa xodimlarni
          direktor panelda o&apos;zi qo&apos;shadi.
        </DialogDescription>
      </DialogHeader>

      <form
        className="flex-1 space-y-5 overflow-y-auto px-4 py-5 sm:px-6"
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
      >
        <fieldset className="space-y-4">
          <legend className="mb-1 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Maktab</legend>
          <FormField id="school-name" label="Maktab nomi" error={shown.name}>
            <Input
              {...field('name')}
              maxLength={LIMITS.name}
              placeholder="24-maktab"
              onChange={(e) => set('name', e.target.value)}
            />
          </FormField>
          <div className="grid gap-4 sm:grid-cols-2">
            <FormField id="school-city" label="Shahar / tuman" error={shown.city}>
              <Input
                {...field('city')}
                maxLength={LIMITS.city}
                placeholder="Toshkent"
                onChange={(e) => set('city', e.target.value)}
              />
            </FormField>
            <FormField
              id="school-shortName"
              label="Qisqa nom (ixtiyoriy)"
              hint={`Panel sarlavhasi uchun, ${LIMITS.shortName} belgigacha. Bo'sh qolsa — nomdan olinadi.`}
              error={shown.shortName}
            >
              <Input
                {...field('shortName')}
                maxLength={LIMITS.shortName}
                placeholder="24-maktab"
                onChange={(e) => set('shortName', e.target.value)}
              />
            </FormField>
          </div>
          <FormField
            id="school-code"
            label="Maktab kodi"
            hint="Direktor panelga kirishda kiritadi. Keyin o'zgarmaydi."
            error={shown.code}
          >
            <Input
              {...field('code')}
              maxLength={40}
              autoCapitalize="none"
              spellCheck={false}
              className="font-mono"
              placeholder="24-maktab-toshkent"
              onChange={(e) => {
                setCodeTouched(true);
                set('code', e.target.value.toLowerCase());
              }}
            />
          </FormField>
        </fieldset>

        <fieldset className="space-y-4">
          <legend className="mb-1 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            Direktor
          </legend>
          <FormField id="school-directorName" label="F.I.Sh." error={shown.directorName}>
            <Input
              {...field('directorName')}
              maxLength={LIMITS.fullName}
              placeholder="Karimov Akmal Rustamovich"
              onChange={(e) => set('directorName', e.target.value)}
            />
          </FormField>
          <FormField
            id="school-directorUsername"
            label="Login"
            hint="Vaqtinchalik parol avtomatik yaratiladi va keyingi oynada bir marta ko'rsatiladi."
            error={shown.directorUsername}
          >
            <Input
              {...field('directorUsername')}
              maxLength={32}
              autoCapitalize="none"
              spellCheck={false}
              className="font-mono"
              onChange={(e) => set('directorUsername', e.target.value.toLowerCase())}
            />
          </FormField>
        </fieldset>
        <button type="submit" hidden aria-hidden tabIndex={-1} />
      </form>

      <div className="flex flex-wrap items-center justify-end gap-2 border-t border-border px-4 py-3 sm:px-6">
        <Button variant="ghost" onClick={onClose}>
          Bekor qilish
        </Button>
        <Button onClick={submit} disabled={create.isPending}>
          {create.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
          Maktabni ochish
        </Button>
      </div>
    </>
  );
}
