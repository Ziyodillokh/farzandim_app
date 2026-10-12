'use client';

import { School, Users, UsersRound } from 'lucide-react';

import type { AudienceKind } from '@/data/contracts';
import { type TKey, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useClassChoices } from '../hooks';
import { SELECTED_TILE, TILE_BUTTON } from '../styles';
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
                'flex items-start gap-3 p-3 text-left transition-all disabled:cursor-not-allowed disabled:opacity-50',
                on ? SELECTED_TILE : TILE_BUTTON,
              )}
            >
              <span
                className={cn(
                  'flex h-9 w-9 shrink-0 items-center justify-center rounded-lg transition-colors',
                  on ? 'bg-brand-gradient text-white shadow-[0_6px_16px_-6px_hsl(var(--primary)/0.6)]' : 'bg-muted text-muted-foreground',
                )}
              >
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
