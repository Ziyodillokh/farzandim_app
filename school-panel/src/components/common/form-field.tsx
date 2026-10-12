'use client';

import type { ReactNode } from 'react';
import type { FieldError } from 'react-hook-form';

import { Label } from '@/components/ui/label';
import { type TKey, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/**
 * Forma maydoni: yorliq + kontrol + xato. Zod xabarlari i18n kalitlari
 * (`errors.form.*`) — shu yerda tarjima qilinadi.
 */
export function FormField({
  label,
  htmlFor,
  error,
  hint,
  children,
  className,
  optional,
}: {
  label: string;
  htmlFor?: string;
  error?: FieldError | { message?: string };
  hint?: string;
  children: ReactNode;
  className?: string;
  optional?: boolean;
}) {
  const { t } = useI18n();
  const message = error?.message;
  return (
    <div className={cn('space-y-1.5', className)}>
      <Label htmlFor={htmlFor} className="flex items-center gap-1">
        {label}
        {optional && <span className="text-xs font-normal text-muted-foreground">({t('common.optional')})</span>}
      </Label>
      {children}
      {message ? (
        <p className="text-xs font-medium text-destructive">{message.startsWith('errors.') ? t(message as TKey) : message}</p>
      ) : (
        hint && <p className="text-xs text-muted-foreground">{hint}</p>
      )}
    </div>
  );
}
