'use client';

import { School, Users, UsersRound } from 'lucide-react';

import type { AudienceKind } from '@/data/contracts';
import { type TKey, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useClassChoices } from '../hooks';
import { ClassMultiSelect } from './class-multi-select';
import { GuardianPicker } from './guardian-picker';

export type AudienceValue = { kind: AudienceKind; classIds: string[]; guardianIds: string[] };

const KINDS: Array<{ kind: AudienceKind; icon: typeof School }> = [
  { kind: 'SCHOOL', icon: School },
  { kind: 'CLASSES', icon: Users },
  { kind: 'GUARDIANS', icon: UsersRound },
];

/**
 * Auditoriya tanlash: butun maktab / sinf(lar) / tanlangan ota-onalar.
 * `canSchool=false` (sinf rahbari) — "Butun maktab" o'chiriladi; sinflar ro'yxati
 * servisning o'zida doiraga cheklangan.
 */
export function AudiencePicker({
  value,
  onChange,
  canSchool,
  knownNames,
  error,
}: {
  value: AudienceValue;
  onChange: (next: AudienceValue) => void;
  canSchool: boolean;
  knownNames?: Record<string, string>;
  error?: string;
}) {
  const { t } = useI18n();
  const classes = useClassChoices();

  return (
    <div className="space-y-4">
      <div className="grid gap-2 sm:grid-cols-3" role="radiogroup" aria-label={t('messages.compose.audience')}>
        {KINDS.map(({ kind, icon: Icon }) => {
          const disabled = kind === 'SCHOOL' && !canSchool;
          const on = value.kind === kind;
          return (
            <button
              key={kind}
              type="button"
              role="radio"
              aria-checked={on}
              disabled={disabled}
              onClick={() => onChange({ ...value, kind })}
              className={cn(
                'flex items-start gap-3 rounded-xl border p-3 text-left transition-all disabled:cursor-not-allowed disabled:opacity-50',
                on ? 'border-primary bg-primary/[0.06] ring-1 ring-primary/30' : 'hover:border-primary/40 hover:bg-accent/50',
              )}
            >
              <span className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-lg', on ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground')}>
                <Icon className="h-4 w-4" />
              </span>
              <span className="min-w-0">
                <span className="block text-sm font-semibold">{t(`enums.audienceKind.${kind}`)}</span>
                <span className="block text-2xs leading-snug text-muted-foreground">{t(`messages.audience.hint.${kind}`)}</span>
              </span>
            </button>
          );
        })}
      </div>

      {value.kind === 'CLASSES' && (
        <ClassMultiSelect
          classes={classes.data?.map((c) => ({ id: c.id, name: c.name, grade: c.grade, size: c.size }))}
          loading={classes.isLoading}
          value={value.classIds}
          onChange={(classIds) => onChange({ ...value, classIds })}
        />
      )}
      {value.kind === 'GUARDIANS' && <GuardianPicker value={value.guardianIds} onChange={(guardianIds) => onChange({ ...value, guardianIds })} knownNames={knownNames} />}
      {!canSchool && <p className="text-2xs text-muted-foreground">{t('messages.compose.scopeHint')}</p>}
      {error && <p className="text-xs font-medium text-destructive">{error.startsWith('errors.') ? t(error as TKey) : error}</p>}
    </div>
  );
}
