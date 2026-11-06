'use client';

import { Save, Undo2 } from 'lucide-react';
import { type FormEvent, useEffect, useRef, useState } from 'react';

import { Button } from '@/components/ui/button';
import { type CareSettingsView, ServiceError } from '@/data/contracts';
import { CARE_SETTINGS_LIMITS, careSettingsInputSchema } from '@/data/schemas/care';
import { useI18n } from '@/i18n';
import { formErrorKey } from '@/lib/errors';
import { useUpdateCareSettings } from '../hooks';
import { isDraftDirty, parseFieldError, type SettingsDraft, toDraft, toInput } from '../lib/settings';
import { HoursSection, type SettingsErrors, SlaSection, StaffSection } from './settings-sections';
import { SettingsPreview } from './settings-preview';

/** Tekshiruv xabarlari uchun o'zgaruvchilar (`{max}` kabi). */
const MESSAGE_VARS = { max: CARE_SETTINGS_LIMITS.displayName, min: 1 } as const;

/**
 * Sozlamalar formasi. Qoralama faqat birinchi chizishda `settings`dan olinadi; keyingi yangilanishlarda
 * (saqlangandan keyin ham) foydalanuvchi yozgani yo'qolmaydi — «o'zgargan»lik joriy `settings` bilan solishtiriladi.
 */
export function CareSettingsForm({ settings, canEdit }: { settings: CareSettingsView; canEdit: boolean }) {
  const { t } = useI18n();
  const save = useUpdateCareSettings();
  const formRef = useRef<HTMLFormElement>(null);
  const saveRef = useRef<HTMLButtonElement>(null);
  const initial = toDraft(settings);
  const [draft, setDraft] = useState<SettingsDraft>(initial);
  const [errors, setErrors] = useState<SettingsErrors>({});
  const dirty = isDraftDirty(draft, initial);

  // Saqlash bajarilayotganda tugma o'chiriladi (fokus yo'qoladi) — tugagach fokus unga qaytadi.
  const wasSaving = useRef(false);
  useEffect(() => {
    if (wasSaving.current && !save.isPending && save.isSuccess) saveRef.current?.focus();
    wasSaving.current = save.isPending;
  }, [save.isPending, save.isSuccess]);
  const disabled = !canEdit || save.isPending;

  const message = (key: string): string => t(formErrorKey(key), MESSAGE_VARS);
  const focusFirstInvalid = () => setTimeout(() => formRef.current?.querySelector<HTMLElement>('[aria-invalid="true"], [data-invalid="true"]')?.focus(), 0);

  const change = (patch: Partial<SettingsDraft>) => {
    setDraft((current) => ({ ...current, ...patch }));
    const touched = Object.keys(patch) as Array<keyof SettingsDraft>;
    if (touched.some((k) => errors[k])) setErrors((current) => Object.fromEntries(Object.entries(current).filter(([k]) => !touched.includes(k as keyof SettingsDraft))));
  };

  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (!canEdit || !dirty) return;
    const parsed = careSettingsInputSchema.safeParse(toInput(draft));
    if (!parsed.success) {
      const next: SettingsErrors = {};
      for (const issue of parsed.error.issues) {
        const field = String(issue.path[0]) as keyof SettingsDraft;
        next[field] ??= message(issue.message);
      }
      setErrors(next);
      focusFirstInvalid();
      return;
    }
    setErrors({});
    save.mutate(parsed.data, {
      onError: (error) => {
        const field = error instanceof ServiceError ? parseFieldError(error.message) : null;
        if (!field) return;
        setErrors({ [field.field]: message(field.key) });
        focusFirstInvalid();
      },
    });
  };

  return (
    <form ref={formRef} onSubmit={submit} noValidate className="grid items-start gap-6 xl:grid-cols-3">
      <div className="min-w-0 space-y-6 xl:col-span-2">
        <StaffSection draft={draft} onChange={change} errors={errors} disabled={disabled} options={settings.staffOptions} />
        <HoursSection draft={draft} onChange={change} errors={errors} disabled={disabled} />
        <SlaSection draft={draft} onChange={change} errors={errors} disabled={disabled} />
      </div>
      <div className="min-w-0 space-y-6 xl:sticky xl:top-20">
        <SettingsPreview draft={draft} options={settings.staffOptions} />
        {canEdit && (
          <div className="flex flex-wrap items-center gap-3">
            <Button ref={saveRef} type="submit" loading={save.isPending} aria-disabled={!dirty} className={dirty ? undefined : 'opacity-50'}>
              <Save />
              {t('care.settings.save')}
            </Button>
            <Button type="button" variant="outline" onClick={() => { setDraft(initial); setErrors({}); }} disabled={!dirty || save.isPending}>
              <Undo2 />
              {t('care.settings.reset')}
            </Button>
            <p role="status" className="text-xs text-muted-foreground">
              {dirty ? t('care.settings.dirty') : t('care.settings.clean')}
            </p>
          </div>
        )}
      </div>
    </form>
  );
}
