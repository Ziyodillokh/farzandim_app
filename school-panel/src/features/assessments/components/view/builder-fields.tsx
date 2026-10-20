'use client';

import type { ReactNode } from 'react';
import { type Control, Controller, type FieldPath, get, useFormState } from 'react-hook-form';

import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { PsychTestInput } from '@/data/schemas/assessments';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { fieldMessage } from '../../lib/labels';

/** Konstruktor maydonlari uchun umumiy yordamchilar (xato matni, ixcham yorliq, tanlov). */
export type BuilderControl = Control<PsychTestInput>;
export type BuilderPath = FieldPath<PsychTestInput>;

export function useFieldError(control: BuilderControl): (path: string) => string | undefined {
  const { t } = useI18n();
  const { errors } = useFormState({ control });
  return (path) => fieldMessage(t, (get(errors, path) as { message?: string } | undefined)?.message);
}

export function Field({ label, htmlFor, error, children, className }: { label: string; htmlFor?: string; error?: string; children: ReactNode; className?: string }) {
  return (
    <div className={cn('space-y-1.5', className)}>
      <Label htmlFor={htmlFor} className="text-xs font-medium text-muted-foreground">
        {label}
      </Label>
      {children}
      {error && <p className="text-xs font-medium text-destructive">{error}</p>}
    </div>
  );
}

export type Choice = { value: string; label: string };

export function SelectField({
  control,
  name,
  choices,
  label,
  error,
  className,
  nullValue,
}: {
  control: BuilderControl;
  name: BuilderPath;
  choices: Choice[];
  label: string;
  error?: string;
  className?: string;
  /** Bu qiymat tanlansa — `null` saqlanadi (masalan, "soha yo'q"). */
  nullValue?: string;
}) {
  return (
    <Field label={label} error={error} className={className}>
      <Controller
        control={control}
        name={name}
        render={({ field }) => (
          <Select
            value={field.value === null && nullValue ? nullValue : String(field.value ?? '')}
            onValueChange={(v) => field.onChange(nullValue && v === nullValue ? null : v)}
          >
            <SelectTrigger className="h-9" aria-label={label}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {choices.map((c) => (
                <SelectItem key={c.value} value={c.value}>
                  {c.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
      />
    </Field>
  );
}
