'use client';

import { AppWindow, Clapperboard, Gamepad2, GraduationCap, Lock, MessageSquare, MessagesSquare, Phone, Siren, type LucideIcon } from 'lucide-react';

import { SectionCard } from '@/components/common/section-card';
import { Checkbox } from '@/components/ui/checkbox';
import { Switch } from '@/components/ui/switch';
import type { AppCategory, SchoolModePolicy } from '@/data/contracts';
import type { ShiftRow } from '@/data/mock/services/school-mode';
import { BLOCKABLE_CATEGORIES, type PolicyPatch } from '@/data/schemas/school-mode';
import { type TKey, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

export const CATEGORY_ICONS: Record<AppCategory, LucideIcon> = {
  GAME: Gamepad2,
  SOCIAL: MessagesSquare,
  VIDEO: Clapperboard,
  EDU: GraduationCap,
  OTHER: AppWindow,
};

const ALWAYS: ReadonlyArray<[LucideIcon, TKey]> = [
  [Phone, 'schoolMode.policies.calls'],
  [MessageSquare, 'schoolMode.policies.sms'],
  [Siren, 'schoolMode.policies.emergencyCalls'],
];

type Props = { policy: SchoolModePolicy; shifts: ShiftRow[]; canManage: boolean; onChange: (patch: PolicyPatch) => void };

function SettingRow({ id, title, hint, checked, disabled, onChange }: { id: string; title: string; hint: string; checked: boolean; disabled: boolean; onChange: (v: boolean) => void }) {
  return (
    <div className="flex items-start justify-between gap-4">
      <label htmlFor={id} className="min-w-0 cursor-pointer">
        <span className="block text-sm font-medium">{title}</span>
        <span className="block text-xs text-muted-foreground">{hint}</span>
      </label>
      <Switch id={id} checked={checked} disabled={disabled} onCheckedChange={onChange} />
    </div>
  );
}

/** Umumiy: yoqilgan, tanaffusda ochish, qaysi smenalar. */
export function GeneralSettings({ policy, shifts, canManage, onChange }: Props) {
  const { t } = useI18n();
  const toggleShift = (id: string, on: boolean) =>
    onChange({ shiftIds: on ? [...policy.shiftIds, id] : policy.shiftIds.filter((s) => s !== id) });
  return (
    <SectionCard title={t('schoolMode.policies.general')}>
      <div className="space-y-5">
        <SettingRow
          id="sm-enabled"
          title={t('schoolMode.policies.enabled')}
          hint={t('schoolMode.policies.enabledHint')}
          checked={policy.enabled}
          disabled={!canManage}
          onChange={(enabled) => onChange({ enabled })}
        />
        <SettingRow
          id="sm-relax"
          title={t('schoolMode.policies.relax')}
          hint={t('schoolMode.policies.relaxHint')}
          checked={policy.relaxDuringBreaks}
          disabled={!canManage}
          onChange={(relaxDuringBreaks) => onChange({ relaxDuringBreaks })}
        />
        <div>
          <p className="text-sm font-medium">{t('schoolMode.policies.shifts')}</p>
          <p className="mb-2 text-xs text-muted-foreground">{t('schoolMode.policies.shiftsHint')}</p>
          <div className="flex flex-wrap gap-3">
            {shifts.map((s) => (
              <label key={s.id} className="flex cursor-pointer items-center gap-2 rounded-lg border px-3 py-2 text-sm">
                <Checkbox checked={policy.shiftIds.includes(s.id)} disabled={!canManage} onCheckedChange={(v) => toggleShift(s.id, v === true)} />
                <span className="font-medium">{s.name}</span>
                <span className="text-xs tabular-nums text-muted-foreground">
                  {s.start}–{s.end}
                </span>
              </label>
            ))}
          </div>
        </div>
      </div>
    </SectionCard>
  );
}

/** Cheklanadigan toifalar (kamida bittasi) va har doim ochiq aloqa. */
export function CategorySettings({ policy, canManage, onChange }: Omit<Props, 'shifts'>) {
  const { t } = useI18n();
  const toggle = (c: (typeof BLOCKABLE_CATEGORIES)[number], on: boolean) => {
    const current = policy.blockedCategories.filter((x): x is (typeof BLOCKABLE_CATEGORIES)[number] => (BLOCKABLE_CATEGORIES as readonly string[]).includes(x));
    onChange({ blockedCategories: on ? [...current, c] : current.filter((x) => x !== c) });
  };
  return (
    <SectionCard title={t('schoolMode.policies.blocked')} description={t('schoolMode.policies.blockedHint')}>
      <div className="grid gap-3 sm:grid-cols-3">
        {BLOCKABLE_CATEGORIES.map((c) => {
          const Icon = CATEGORY_ICONS[c];
          const on = policy.blockedCategories.includes(c);
          const last = on && policy.blockedCategories.length <= 1;
          return (
            <label
              key={c}
              className={cn(
                'flex cursor-pointer flex-col gap-3 rounded-xl border p-4 transition-colors',
                on ? 'border-primary/40 bg-primary/[0.04]' : 'bg-card',
                !canManage && 'cursor-default',
              )}
            >
              <div className="flex items-center justify-between">
                <span className={cn('flex h-10 w-10 items-center justify-center rounded-xl', on ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground')}>
                  <Icon className="h-5 w-5" aria-hidden />
                </span>
                <Switch checked={on} disabled={!canManage || last} onCheckedChange={(v) => toggle(c, v)} aria-label={t(`enums.appCategory.${c}`)} />
              </div>
              <div>
                <p className="text-sm font-semibold">{t(`enums.appCategory.${c}`)}</p>
                <p className="text-xs text-muted-foreground">{t(`schoolMode.policies.categoryHint.${c}`)}</p>
              </div>
            </label>
          );
        })}
      </div>
      <div className="mt-5 rounded-xl border border-success/30 bg-success/5 p-4">
        <div className="mb-3 flex flex-wrap items-baseline justify-between gap-2">
          <p className="text-sm font-semibold">{t('schoolMode.policies.alwaysAllowed')}</p>
          <p className="text-xs text-muted-foreground">{t('schoolMode.policies.alwaysAllowedHint')}</p>
        </div>
        <ul className="grid gap-2 sm:grid-cols-3">
          {ALWAYS.map(([Icon, key]) => (
            <li key={key} className="flex items-center gap-2.5 rounded-lg bg-card px-3 py-2.5 text-sm shadow-soft">
              <Icon className="h-4 w-4 shrink-0 text-success" aria-hidden />
              <span className="min-w-0 flex-1 font-medium">{t(key)}</span>
              <Lock className="h-3.5 w-3.5 shrink-0 text-muted-foreground" aria-label={t('schoolMode.policies.locked')} />
            </li>
          ))}
        </ul>
      </div>
    </SectionCard>
  );
}
