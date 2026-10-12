'use client';

import { ImageIcon } from 'lucide-react';

import { useI18n } from '@/i18n';
import { audit as auditDict } from '@/i18n/uz/audit';
import { cn } from '@/lib/utils';

const MAX_TEXT = 140;
const MAX_LIST = 6;

type FieldKey = keyof typeof auditDict.fields;

function isFieldKey(key: string): key is FieldKey {
  return key in auditDict.fields;
}

/** Maydon nomi: ma'lum bo'lsa tarjima, aks holda texnik kalit. */
export function FieldLabel({ field }: { field: string }) {
  const { t } = useI18n();
  const leaf = field.split('.').at(-1) ?? field;
  if (isFieldKey(leaf)) {
    const prefix = field.includes('.') ? `${field.split('.').slice(0, -1).join('.')} · ` : '';
    return (
      <span className="font-medium">
        {prefix && <span className="text-muted-foreground">{prefix}</span>}
        {t(`audit.fields.${leaf}`)}
      </span>
    );
  }
  return <code className="rounded bg-muted px-1.5 py-0.5 text-xs">{field}</code>;
}

/** Qiymatni o'qiladigan ko'rinishga keltirish (rasm, ro'yxat, ha/yo'q…). */
export function DiffValue({ value, className }: { value: unknown; className?: string }) {
  const { t } = useI18n();
  const base = cn('break-words text-sm', className);
  if (value === null || value === undefined || value === '') return <span className={cn(base, 'text-muted-foreground')}>—</span>;
  if (typeof value === 'boolean') return <span className={base}>{value ? t('common.yes') : t('common.no')}</span>;
  if (typeof value === 'number') return <span className={cn(base, 'tabular-nums')}>{value}</span>;
  if (typeof value === 'string') {
    if (value.startsWith('data:image/')) {
      return (
        <span className={cn(base, 'inline-flex items-center gap-2')}>
          {/* eslint-disable-next-line @next/next/no-img-element -- data URL */}
          <img src={value} alt="" className="h-8 w-8 rounded-md border bg-white object-contain" />
          <ImageIcon className="h-3.5 w-3.5 text-muted-foreground" />
          {t('audit.detail.image')}
        </span>
      );
    }
    return <span className={base}>{value.length > MAX_TEXT ? `${value.slice(0, MAX_TEXT)}…` : value}</span>;
  }
  if (Array.isArray(value)) {
    if (value.length === 0) return <span className={cn(base, 'text-muted-foreground')}>—</span>;
    const primitives = value.every((v) => typeof v === 'string' || typeof v === 'number');
    if (!primitives) return <span className={base}>{t('audit.detail.items', { count: value.length })}</span>;
    const shown = value.slice(0, MAX_LIST).join(', ');
    return <span className={base}>{value.length > MAX_LIST ? `${shown} +${value.length - MAX_LIST}` : shown}</span>;
  }
  const json = JSON.stringify(value);
  return <code className={cn(base, 'font-mono text-xs')}>{json.length > MAX_TEXT ? `${json.slice(0, MAX_TEXT)}…` : json}</code>;
}
